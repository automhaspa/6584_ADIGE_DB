SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Gest_Liste_Prelievo_Mancanti]
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),	
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	-- SET LOCK_TIMEOUT;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30);
	DECLARE @TranCount				INT;
	DECLARE @Return					INT;
	DECLARE @ErrLog					VARCHAR(500);

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure	= Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @ErroreCreaMissione				VARCHAR(MAX)
		DECLARE @Id_Tipo_Missione				VARCHAR(3) = 'OUM'

		DECLARE @Id_Udc							INT
		DECLARE @Id_Partizione_Sorg				INT
		DECLARE @Id_Partizione_Destinazione		INT
		DECLARE @Flag_SvuotaComp				BIT
		DECLARE @Id_Testata						INT
		DECLARE @Id_Riga						INT
		DECLARE @Id_Tipo_Udc					VARCHAR(2)

		--Raggruppo l'udc 
		DECLARE CursorTasks CURSOR LOCAL FAST_FORWARD FOR
			SELECT	MD.Id_Udc,
					UP.Id_Partizione,
					MD.Id_Partizione_Destinazione,
					MD.Flag_SvuotaComplet,
					MD.Id_Testata_Lista,
					MD.Id_Riga_Lista,
					UT.Id_Tipo_Udc
			FROM	dbo.Missioni_Picking_Dettaglio	MD
			JOIN	Udc_Posizione					UP	ON up.Id_Udc = MD.Id_Udc
				AND ISNULL(MD.FL_MANCANTI,0) = 1
				AND Id_Stato_Missione = 1
				AND MD.Id_Udc <> 702
			JOIN	Udc_Testata						UT
			ON		UT.Id_Udc = UP.Id_Udc
			JOIN	Partizioni						P	ON up.Id_Partizione = p.ID_PARTIZIONE
				AND P.ID_TIPO_PARTIZIONE = 'MA'
			LEFT
			JOIN	Missioni						M
			ON		M.Id_Udc = MD.Id_Udc
			WHERE	M.ID_MISSIONE IS NULL	--UDC NON IN MISSIONE
			GROUP
				BY	MD.Id_Udc,
					UP.Id_Partizione,
					MD.Id_Partizione_Destinazione,
					MD.Flag_SvuotaComplet,
					MD.Id_Testata_Lista,
					MD.Id_Riga_Lista,
					UT.Id_Tipo_Udc
			ORDER
				BY	Flag_SvuotaComplet,
					MD.Id_Testata_Lista

		OPEN CursorTasks
		FETCH NEXT FROM CursorTasks INTO
				@Id_Udc,
				@Id_Partizione_Sorg,
				@Id_Partizione_Destinazione,
				@Flag_SvuotaComp,
				@Id_Testata,
				@Id_Riga,
				@Id_Tipo_Udc
				
		WHILE @@FETCH_STATUS = 0
		BEGIN
			DECLARE @PostiLiberiBuffer		INT = 0

			--Setto l'Id tipo missione --Se di tipo A
			IF @Id_Tipo_Udc IN ('1','2','3')
				SELECT	@PostiLiberiBuffer = PostiLiberiBuffer
				FROM	Custom.vBufferMissioni	vb
				JOIN	SottoAree				sa	ON SA.ID_SOTTOAREA = VB.Id_Sottoarea
				JOIN	Componenti				c	ON sa.ID_SOTTOAREA = c.ID_SOTTOAREA
				JOIN	SottoComponenti			sc	ON sc.ID_COMPONENTE = c.ID_COMPONENTE
				JOIN	Partizioni				p	ON p.ID_SOTTOCOMPONENTE = sc.ID_SOTTOCOMPONENTE
					AND P.ID_PARTIZIONE = @Id_Partizione_Destinazione
				WHERE	vb.Tipo_Missione =	CASE
												WHEN @Id_Tipo_Missione IN ('OUK','OUL') THEN 'OUM'
												ELSE 'OUL'
											END
			ELSE IF @Id_Tipo_Udc IN ('4','5','6')
				SELECT	@PostiLiberiBuffer = PostiLiberiBuffer
				FROM	Custom.vBufferMissioni
				WHERE	Id_Sottoarea = 32
			
			IF @PostiLiberiBuffer > 0
			BEGIN
				BEGIN TRY
					EXEC dbo.sp_Insert_CreaMissioni
								@Id_Udc						= @Id_Udc,
								@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
								@Id_Tipo_Missione			= 'OUM',
								@Xml_Param					= '',
								@Id_Processo				= @Id_Processo,
								@Origine_Log				= @Origine_Log,
								@Id_Utente					= @Id_Utente,
								@Errore						= @Errore		OUTPUT

						--Controllo se non ho errori in fase di creazione Missione  (Tipo percorso non trovato se la partizione e' in lock) altrimenti lascio in stato 1
					IF ISNULL(@Errore,'')=''
						UPDATE	Missioni_Picking_Dettaglio
						SET		Id_Stato_Missione = 2
						WHERE	Id_Udc = @Id_Udc
							AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione
							AND Id_Testata_Lista = @Id_Testata
							AND Id_Riga_Lista = @Id_Riga
							AND Id_Stato_Missione = 1
							AND FL_MANCANTI = 1
				END TRY
				BEGIN CATCH
					SET @ErroreCreaMissione = CONCAT('ERRORE CREAZIONE MISSIONE UDC: ', @Errore, ' Id_Udc : ' , @Id_Udc, ' Verso:', @Id_Partizione_Destinazione, '  ', ERROR_MEssage())

					EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @ErroreCreaMissione,
							@Errore				= @Errore OUTPUT;
				END CATCH
			END
			
			FETCH NEXT FROM CursorTasks INTO
				@Id_Udc,
				@Id_Partizione_Sorg,
				@Id_Partizione_Destinazione,
				@Flag_SvuotaComp,
				@Id_Testata,
				@Id_Riga,
				@Id_Tipo_Udc
		END

		CLOSE CursorTasks
		DEALLOCATE CursorTasks

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION;
		-- Return 0 se tutto è andato a buon fine;
		RETURN 0;
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE();
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
			BEGIN
				ROLLBACK TRANSACTION;

				EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @Errore,
					@Errore				= @Errore OUTPUT;
			
				-- Return 1 se la procedura è andata in errore;
				RETURN 1;
			END
		ELSE
			THROW;
	END CATCH;
END;
GO
