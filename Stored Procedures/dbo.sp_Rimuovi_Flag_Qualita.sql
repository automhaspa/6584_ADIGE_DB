SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [dbo].[sp_Rimuovi_Flag_Qualita]
	@Id_UdcDettaglio			INT,
	@FlagControlloQualita		INT,
	@MotivoQualita				VARCHAR(20) = NULL,
	@CONTROL_LOT				VARCHAR(40)	= NULL,
	--QUANTITA DA CONTROLLARE
	@Quantita_Pezzi				NUMERIC(10,2),
	--RAPPRESENTA LA QUANTITA CONFORME
	@QuantitaConforme			NUMERIC(10,2) = 0, 
	@QtaNonConforme				NUMERIC(10,2) = 0,
	--SE ARRIVO DA UDC_DETTAGLIO
	@MotivoNonConformita		VARCHAR(500) = NULL,
	@DA_SAP						BIT			= 0,
	@Id_Partizione_Evento		INT			= NULL,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(32),	
	@Errore						VARCHAR(500) OUTPUT
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
		DECLARE @FL_STORNO					VARCHAR(1)
		DECLARE @Id_Udc						INT
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @Id_Articolo				INT
		
		DECLARE @Wbs_Riferimento			VARCHAR(40)
		DECLARE @Qta_A_Progetto				INT
		
		SELECT	@Id_Udc = UP.Id_Udc,
				@Id_Articolo = UD.Id_Articolo,
				@Id_Partizione_Destinazione = UP.ID_Partizione,
				@Wbs_Riferimento = UD.WBS_Riferimento
		FROM	Udc_Dettaglio				UD
		JOIN	Udc_Posizione				UP
		ON		UD.Id_Udc = UP.Id_Udc
		WHERE	UD.Id_UdcDettaglio = @Id_UdcDettaglio

		IF (@Id_Udc = 702)
			THROW 50001, ' OPERAZIONE NON ESEGUIBILE SU MODULA DA AWM', 1;
		IF (@FlagControlloQualita = 0)
			THROW 50002, ' FUNZIONE UTILIZZABILE ESCLUSIVAMENTE SU ARTICOLI MARCHIATI DA CONTROLLO QUALITA',1;
		IF (@Quantita_Pezzi = 0)
			THROW 50005, 'L'' ARTICOLO SELEZIONATO NON HA FLAG CONTROLLO QUALITA',1;
		
		IF (@QuantitaConforme + @QtaNonConforme > @Quantita_Pezzi)
			THROW 50001, 'LA SOMMA TRA LA QUANTITA NON CONFORME E LA QUANTITA CONFORME DEVONO CORRISPONDERE ALLA QUANTITA DA CONTROLLARE', 1;
		
		IF (@QtaNonConforme < 0 OR @QuantitaConforme < 0)
			THROW 50002, ' INSERITA QUANTITA NON VALIDA',1
			
		IF @DA_SAP = 0 AND EXISTS (SELECT TOP(1) 1 FROM Custom.ControlloQualita WHERE Id_UdcDettaglio = @Id_UdcDettaglio AND ISNULL(Doppio_Step_QM,0) = 1)
			THROW 50009,'LA RIMOZIONE DEL CONTROLLO QUALITA'' VERRA'' FATTO IN AUTOMATICO CON SAP',1

		--LO FACCIO QUI COSI PULISCO LA TABELLA
		IF	@QtaNonConforme > 0
				OR
			@QuantitaConforme > 0
		BEGIN
			--Elimino dalla tabella controllo
			UPDATE	Custom.ControlloQualita
			SET		Quantita = Quantita - @QuantitaConforme - @QtaNonConforme
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
				AND ISNULL(@CONTROL_LOT,'') = ISNULL(CONTROL_LOT,'')

			IF NOT EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.ControlloQualita
								WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
									AND ISNULL(@CONTROL_LOT,'') = ISNULL(CONTROL_LOT,'')
									AND Quantita > 0
							)
				DELETE	Custom.ControlloQualita
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
					AND ISNULL(@CONTROL_LOT,'') = ISNULL(CONTROL_LOT,'')
		END
		
		IF @QuantitaConforme > 0
		BEGIN
			--CONSUNTIVO DI SBLOCCO PER LA QUANTITA CONFORME
			EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
						@IdCausaleL3		= 'RBL',
						@IdUdcDettaglio		= @Id_UdcDettaglio,
						@IdCausaleMovimento = 3,
						@Quantity			= @QuantitaConforme,
						@WBS_CODE			= @Wbs_Riferimento,
						@CONTROL_LOT		= @CONTROL_LOT,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore OUTPUT

			IF ISNULL(@Errore, '') <> ''
				RAISERROR(@Errore, 12, 1)

			--VERIFICO SE ESITONO MANCANTI LEGATI A QUESTO DETTAGLIO E NEL CASO LANCIO L'EVENTO MANCANTE. VERIFICO ANCHE LA WBS ANCHE SE DOVREBBE ESSERE GIUSTA.
			IF EXISTS	(
							SELECT	TOP(1) 1
							FROM	Custom.AnagraficaMancanti	AM
							JOIN	Udc_Dettaglio				UD
							ON		AM.Id_Articolo = UD.Id_Articolo
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
								AND AM.Qta_Mancante > 0
								AND ISNULL(AM.WBS_Riferimento,'') = ISNULL(@Wbs_Riferimento,'')
						)
					AND
				EXISTS	(
							SELECT	TOP(1) 1
							FROM	Udc_Dettaglio	UD
							JOIN	Udc_Testata		UT
							ON		UD.Id_Udc = UT.Id_Udc
							JOIN	Udc_Posizione	UP
							ON		UP.Id_Udc = UT.Id_Udc
							JOIN	Baie			B
							ON		UP.Id_Partizione = B.Id_Partizione
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
						)
			BEGIN
				--lancio l'evento di picking MANCANTE
				DECLARE @XmlParam xml = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Missione_Modula>',0,'</Missione_Modula></Parametri>')
				
				IF @Id_Partizione_Evento IS NULL
					SET @Id_Partizione_Evento = @Id_Partizione_Destinazione

				EXEC @Return = sp_Insert_Eventi
							@Id_Tipo_Evento		= 36,
							@Id_Partizione		= @Id_Partizione_Evento,
							@Id_Tipo_Messaggio	= 1100,
							@XmlMessage			= @XmlParam,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore OUTPUT

				IF @Return <> 0
					RAISERROR(@Errore,12,1)
			END
		END

		IF @QtaNonConforme > 0
		BEGIN
			DECLARE @CAUSALE_L3 VARCHAR(3)

			IF NOT EXISTS	(
								SELECT	TOP 1 1
								FROM	[Custom].[NonConformita]
								WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
									AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
							)
				INSERT INTO [Custom].[NonConformita]
					([Id_UdcDettaglio],[Quantita],[MotivoNonConformita],CONTROL_LOT)
				VALUES
					(@Id_UdcDettaglio,@QtaNonConforme,@MotivoNonConformita,ISNULL(@CONTROL_LOT,''))
			ELSE
				UPDATE	[Custom].[NonConformita]
				SET		Quantita = Quantita + @QtaNonConforme,
						MotivoNonConformita = CASE WHEN ISNULL(@MotivoNonConformita,'') = '' THEN MotivoNonConformita ELSE @MotivoNonConformita END
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
					AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')

			IF ISNULL(@CONTROL_LOT,'') <> ''
				SET @CAUSALE_L3 = 'BLS'
			ELSE
				SET @CAUSALE_L3 = 'RBL'

			EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
						@IdCausaleL3			= @CAUSALE_L3,
						@IdUdcDettaglio			= @Id_UdcDettaglio,
						@IdCausaleMovimento		= 3,
						@Flag_ControlloQualita	= 1,
						@Quantity				= @QtaNonConforme,
						@WBS_CODE				= @Wbs_Riferimento,
						@CONTROL_LOT			= @CONTROL_LOT,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore OUTPUT
			
			INSERT INTO [L3INTEGRATION].[dbo].[HOST_NON_COMPLIANT_STOCK]
				SELECT	GETDATE(), 0, NULL, @Id_Utente, a.Codice, roe.CONTROL_LOT, @QtaNonConforme, 0
				FROM	Udc_Dettaglio		ud
				JOIN	Articoli			a
				ON		a.Id_Articolo = ud.Id_Articolo
				JOIN	Custom.RigheOrdiniEntrata roe
				ON		roe.Id_Testata = ud.Id_Ddt_Reale
					AND roe.LOAD_LINE_ID = ud.Id_Riga_Ddt
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		END

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
