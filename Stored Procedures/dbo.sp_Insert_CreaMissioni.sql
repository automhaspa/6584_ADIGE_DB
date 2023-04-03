SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Insert_CreaMissioni]
	@Id_Udc							VARCHAR(MAX)	= NULL,
	@ID_PARTIZIONE_SORGENTE			INT				= NULL,
	@Id_Partizione_Destinazione		INT				= NULL,
	@Id_Gruppo_Lista				INT				= NULL,
	@Id_Tipo_Missione				VARCHAR(3),
	@Id_Missione					INT				= NULL		OUTPUT,
	@Priorita						INT				= NULL,
	@Id_Raggruppa_Udc				INT				= NULL,
	@Xml_Param						XML				= NULL,
	@Id_Articolo					INT				= NULL,
	@QUOTADEPOSITOX					INT				= NULL,
	-- Parametri Standard;
	@Id_Processo					VARCHAR(30),
	@Origine_Log					VARCHAR(25),
	@Id_Utente						VARCHAR(32),
	@Errore							VARCHAR(500)				OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	SET LOCK_TIMEOUT 5000

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @Pos							INT
		DECLARE @IdTipoUdc						VARCHAR(1)
		DECLARE @Id_Udc_Controllo				INT = CAST(@Id_Udc AS INT)
		DECLARE @IdPartizioneUdc				INT
		DECLARE @PostiLiberiBuffer				INT	= 0
		DECLARE @Codice_Udc						VARCHAR(30)
		DECLARE @ErrMsg							VARCHAR(MAX) = ''
		DECLARE @TipoPartizioneUdc				VARCHAR(3)
		DECLARE @Codice_Articolo				VARCHAR(50)
		DECLARE @Msg_Finale						VARCHAR(50)
		
		DECLARE @WkTable						TABLE
		(
			Id_Udc							INT,
			Id_Componente_Sorgente			INT,
			Id_Tipo_Componente_Sorgente		VARCHAR(1),
			Id_SottoComponente_Sorgente		INT,
			Id_Partizione_Sorgente			INT,
			Id_Partizione_Traslo			INT,
			Id_Raggruppa_Udc				INT,
			Codice_Abbreviato				VARCHAR(4)
		)

		SELECT	@IdTipoUdc			= UT.Id_Tipo_Udc,
				@IdPartizioneUdc	= UP.Id_Partizione,
				@TipoPartizioneUdc	= P.ID_TIPO_PARTIZIONE,
				@Codice_Udc			= UT.Codice_Udc
		FROM	dbo.Udc_Testata			UT
		JOIN	dbo.Udc_Posizione		UP
		ON		UP.Id_Udc = UT.Id_Udc
		JOIN	dbo.Partizioni			P
		ON		P.Id_Partizione = UP.Id_Partizione
		WHERE	UT.Id_Udc = @Id_Udc_Controllo

		IF @Id_Tipo_Missione = 'CQL'
		BEGIN
			IF @TipoPartizioneUdc <> 'MA'
				THROW 50001, 'MISSIONI DI CONTROLLO QUALITA AVVIABILI SOLO SE L''UDC SI TROVA IN UNA PARTIZIONE DI MAGAZZINO',1
			
			IF @IdTipoUdc IN ('4', '5', '6')
			BEGIN
				SET @Id_Partizione_Destinazione = 3203

				SELECT	@PostiLiberiBuffer = PostiLiberiBuffer
				FROM	Custom.vBufferMissioni
				WHERE	Id_Sottoarea =	(
											SELECT	C.ID_SOTTOAREA
											FROM	Componenti		C
											JOIN	SottoComponenti SC
											ON		SC.ID_COMPONENTE = C.ID_COMPONENTE
											JOIN	Partizioni		P
											ON		P.ID_SOTTOCOMPONENTE = SC.ID_SOTTOCOMPONENTE
											WHERE	ID_PARTIZIONE = @Id_Partizione_Destinazione
										)
										
				SET @Msg_Finale = 'UDC SELEZIONATA DI TIPO B. USCITA VERSO 3B03'

				IF (@PostiLiberiBuffer <= 0)
				BEGIN
					SET @ErrMsg =  CONCAT('IMPOSSIBILE CREARE LA MISSIONE PER UDC: ', @Codice_Udc ,' VERSO LA BAIA ',@Id_Partizione_Destinazione,
											' LE RULLIERE DI BUFFER SONO/SARANNO OCCUPATE DA MISSIONI GIA ATTIVE ', @Origine_Log);
					THROW 50006, @ErrMsg, 1;
				END
			END
		END

		--Non permetto l'outbound di un Udc che è impegnata in una lista attiva
		IF @Id_Tipo_Missione = 'OUP'
		BEGIN
			IF @Id_Udc_Controllo = 702
				THROW 50001, 'UDC NON MOVIMENTABILE', 1

			IF EXISTS(SELECT 1 FROM Missioni_Picking_Dettaglio WHERE Id_Stato_Missione = 1 AND Id_Udc = @Id_Udc)
				THROW 50001, 'UDC GIA'' IMPEGNATA IN UNA LISTA DI PRELIEVO',1;

			--SE ho un evento attivo sulla baia di Picking Lista o Picking Manuale non faccio partire la missione
			IF EXISTS(SELECT 1 FROM Eventi WHERE Id_Partizione = @IdPartizioneUdc AND Id_Tipo_Evento in (3,4) AND Id_Tipo_Stato_Evento = 1 )
				THROW 50005, 'IMPOSSIBILE FORZARE MISSIONI MANUALI SE C''E'' UN EVENTO DI PICKING ATTIVO SULL UDC', 1;

			--Le udc di tipo  B possono andare solamente in 3B03
			IF @IdTipoUdc IN ('4','5','6') AND @Id_Partizione_Destinazione <> 3203
				THROW 50002, 'LE UDC DI TIPO B POSSONO ANDARE ESCLUSIVAMENTE VERSO LA BAIA 3B03', 1;

			--SE E UN OUP LA CONSIDERO SUL BUFFER OUL
			SELECT	@PostiLiberiBuffer = PostiLiberiBuffer
			FROM	Custom.vBufferMissioni
			WHERE	Id_Sottoarea =	(
										SELECT	C.ID_SOTTOAREA
										FROM	dbo.Componenti		C
										JOIN	dbo.SottoComponenti SC
										ON		SC.ID_COMPONENTE = C.ID_COMPONENTE
										JOIN	dbo.Partizioni		P
										ON		P.ID_SOTTOCOMPONENTE = SC.ID_SOTTOCOMPONENTE
										WHERE	P.ID_PARTIZIONE = @Id_Partizione_Destinazione
									)
				AND	Tipo_Missione = CASE
										WHEN (@Id_Partizione_Destinazione NOT IN (3203, 3701)) THEN 'OUL'
										ELSE ''
									END

			IF @PostiLiberiBuffer <= 0
			BEGIN
				SET @ErrMsg =  CONCAT('IMPOSSIBILE CREARE LA MISSIONE PER UDC: ', @Codice_Udc ,' VERSO ', @Id_Partizione_Destinazione,
										'. LE RULLIERE DI BUFFER SONO/SARANNO OCCUPATE DA MISSIONI GIA ATTIVE ', @Origine_Log);
				THROW 50006, @ErrMsg, 1;
			END
		END

		-- Inserimento del codice;
		IF @Priorita IS NULL
			SELECT	@Priorita = Priorita
			FROM	dbo.Tipo_Missioni
			WHERE	Id_Tipo_Missione = @Id_Tipo_Missione

		SET @Xml_Param = '<Parametri>' + ISNULL(CONVERT(Varchar(MAX),@Xml_Param),'') + '</Parametri>'

		IF @Id_Articolo IS NOT NULL
		BEGIN
			SELECT	@Codice_Articolo = Codice
			FROM	Articoli
			WHERE	Id_Articolo = @Id_Articolo

			SET @Xml_Param.modify('insert <Codice_Articolo>{sql:variable("@Codice_Articolo")}</Codice_Articolo> into (//Parametri)[1]')
		END

		IF RIGHT(@Id_Udc,1) <> ';'  SET @Id_Udc = @Id_Udc + ';'
		BEGIN
			WHILE	(ISNULL(@Pos,CHARINDEX(';',@Id_Udc)) <> 0)
						OR
					@ID_PARTIZIONE_SORGENTE IS NOT NULL
			BEGIN
				DECLARE @ID_PARTIZIONE_SORGENTE_TMP	INT = NULL
				DECLARE @ID_UDC_TMP					INT = NULL

				IF EXISTS(SELECT TOP 1 1 FROM dbo.Missioni WHERE Id_Stato_Missione IN ('NEW','ELA','ESE') AND Id_Udc = @Id_Udc_Controllo)
					THROW 50001, 'ERRORE: UDC GIA IN MISSIONE', 1

				IF @ID_PARTIZIONE_SORGENTE IS NOT NULL
				BEGIN
					SET @ID_PARTIZIONE_SORGENTE_TMP = @ID_PARTIZIONE_SORGENTE
					SET @ID_PARTIZIONE_SORGENTE = NULL
				END
				ELSE
				BEGIN
					SET @ID_UDC_TMP = SUBSTRING(@Id_Udc,1,ISNULL(@Pos,CHARINDEX(';',@Id_Udc)) - 1)

					SELECT	@ID_PARTIZIONE_SORGENTE_TMP = ID_PARTIZIONE
					FROM	dbo.Udc_Posizione
					WHERE	Id_Udc = @ID_UDC_TMP
				END

				-- Inserimento della missione;
				INSERT INTO dbo.Missioni
					(Id_Partizione_Sorgente,Id_Partizione_Destinazione,Id_Udc,Id_Stato_Missione,Id_Tipo_Missione,Priorita,Id_Raggruppa_Udc,Id_Gruppo_Lista,Xml_Param,QUOTADEPOSITOX)
				VALUES
					(@ID_PARTIZIONE_SORGENTE_TMP,@Id_Partizione_Destinazione,@ID_UDC_TMP,'NEW',@Id_Tipo_Missione,@Priorita,@Id_Raggruppa_Udc,@Id_Gruppo_Lista,@Xml_Param,@QUOTADEPOSITOX)

				SELECT @Id_Missione  = SCOPE_IDENTITY()

				BEGIN TRY
					EXEC sp_Cerca_Percorso
							@Id_Partizione_Sorgente		= @ID_PARTIZIONE_SORGENTE_TMP,
							@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
							@Id_Missione				= @Id_Missione,
							@Steps						= @Xml_Param,
							@Id_Tipo_Missione			= @Id_Tipo_Missione,
							@Id_Processo				= @Id_Processo,
							@Origine_Log				= @Origine_Log,
							@Id_Utente					= @Id_Utente,
							@Errore						= @Errore			OUTPUT

					IF (ISNULL(@Errore, '') <> '')
						THROW 50001, @Errore, 1

					EXEC sp_Update_Stato_Missioni
								@Id_Missione = @Id_Missione
								,@Id_Stato_Missione = 'ELA'
								,@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Id_Utente = @Id_Utente
								,@Errore = @Errore OUTPUT
								
						IF (ISNULL(@Errore, '') <> '')
							THROW 50001, @Errore, 1;
				END TRY
				BEGIN CATCH
					DELETE	Percorso_PreCalc
					WHERE	Id_Partizione_Sorgente = @ID_PARTIZIONE_SORGENTE_TMP
						AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione

					EXEC sp_Update_Stato_Missioni
								@Id_Missione = @Id_Missione
								,@Id_Stato_Missione = 'IMP'
								,@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Id_Utente = @Id_Utente
								,@Errore = @Errore OUTPUT

					SET @Errore = 'percorsoNotFound'
				END CATCH
				
				SET @Id_Udc = SUBSTRING(@Id_Udc,ISNULL(@Pos,CHARINDEX(';',@Id_Udc)) + 1,LEN(@Id_Udc))
				SET @Pos = CHARINDEX(';',@Id_Udc)
			END
		END

		IF @Msg_Finale IS NOT NULL
			SET @Errore = @Msg_Finale

		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
		BEGIN
			ROLLBACK TRANSACTION
			
			EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Proprieta_Log = @Nome_StoredProcedure
								,@Id_Utente = @Id_Utente
								,@Id_Tipo_Log = 4
								,@Id_Tipo_Allerta = 0
								,@Messaggio = @Errore
								,@Errore = @Errore OUTPUT			
		
			-- Return 0 se la procedura è andata in errore;
			RETURN 1
		END
		ELSE THROW
	END CATCH
END
GO
