SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Sposta_Articolo_Udc]
	--ID UDC DETTAGLIO  SORGENTE
	@Id_UdcDettaglio		INT,
	--ID UDC DESTINAZIONE
	@Id_Udc					INT,
	--Quantita Da Spostare
	@Quantita				NUMERIC(10,2),
	@FlagControlloQualita	BIT,
	@FlagNonConformita		BIT,
	@Quantita_Pezzi			NUMERIC(10,2),
	-- Parametri Standard;
	@Id_Processo			VARCHAR(30),
	@Origine_Log			VARCHAR(25),
	@Id_Utente				VARCHAR(32),	
	@Errore					VARCHAR(500) OUTPUT
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
		DECLARE @Id_Articolo			INT
		DECLARE	@Udc_Dettaglio_Dest		INT
		DECLARE	@Id_Udc_Sorgente		INT
		DECLARE	@WBS_CODE				VARCHAR(24)

		DECLARE @MOTIVO_QUALITA			VARCHAR(MAX)
		DECLARE @DOPPIO_STEP_QM			INT
		DECLARE @QTA_QUALITA			NUMERIC(18,4)
		DECLARE @CONTROL_LOT			VARCHAR(45)
		
		SELECT	@Id_Articolo		= Id_Articolo,
				@Id_Udc_Sorgente	= Id_Udc,
				@WBS_CODE			= WBS_Riferimento
		FROM	Udc_Dettaglio
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		
		IF (@Id_Udc_Sorgente = 702)
			THROW 50001, ' OPERAZIONE NON ESEGUIBILE SU MODULA DA AWM', 1

		--IF (@FlagControlloQualita = 1)
		--	THROW 50001, ' IMPOSSIBILE MOVIMENTARE QUANTITA SOGGETTA A CONTROLLO QUALITA',1;

		IF (@FlagNonConformita = 1)
			THROW 50001, ' IMPOSSIBILE MOVIMENTARE QUANTITA NON CONFORME',1;

		IF (@Quantita <= 0)
			THROW 50001, ' QUANTITA NON VALIDA',1;

		IF (@Quantita > @Quantita_Pezzi)
			THROW 50001, ' IMPOSSIBILE MOVIMENTARE UNA QUANTITA MAGGIORE RISPETTO A QUELLA CONFORME',1;

		IF @FlagControlloQualita = 1 OR EXISTS (SELECT TOP 1 1 FROM Custom.ControlloQualita WHERE Id_UdcDettaglio = @Id_UdcDettaglio)
		BEGIN
			SET @FlagControlloQualita = 1

			SELECT	@MOTIVO_QUALITA		= MotivoQualita,
					@DOPPIO_STEP_QM		= Doppio_Step_QM,
					@QTA_QUALITA		= Quantita,
					@CONTROL_LOT		= CONTROL_LOT
			FROM	Custom.ControlloQualita
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		END

		--IF EXISTS (SELECT TOP 1 1 FROM Missioni_Picking_Dettaglio WHERE Id_UdcDettaglio = @Id_UdcDettaglio AND Id_Stato_Missione <> 4)
		IF	(
				SELECT	@Quantita_Pezzi - SUM(Quantita)
				FROM	Missioni_Picking_Dettaglio	MPD
				JOIN	Udc_Dettaglio				UD
				ON		UD.Id_UdcDettaglio = MPD.Id_UdcDettaglio
				WHERE	UD.Id_UdcDettaglio = @Id_UdcDettaglio
					AND Id_Stato_Missione NOT IN (3,4,5)
			) < @Quantita
			THROW 50009, 'DETTAGLIO COINVOLTO IN UNA LISTA DI PICKING NON ANCORA CONCLUSA. IMPOSSIBILE SPOSTARE',1

		--Prelevo da Udc Sorgente
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
					@Id_UdcDettaglio		= @Id_UdcDettaglio,
					@Qta_Pezzi_Input		= @Quantita,
					@Id_Causale_Movimento	= 2,
					@Id_Processo			= @Id_Processo,
					@Origine_Log			= @Origine_Log,
					@Id_Utente				= @Id_Utente,
					@Errore					= @Errore OUTPUT

		IF ISNULL(@Errore, '') <> ''
			THROW 50003 ,@Errore, 1

		SELECT	@Udc_Dettaglio_Dest = Id_UdcDettaglio
		FROM	Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @Id_Articolo
			AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_CODE,'')

		IF @Id_Udc = 702 AND ISNULL(@WBS_CODE,'') = ''
			THROW 50009, 'IMPOSSIBILE SPOSTARE SU MODULA DEL MATERIALE A PROGETTO',1

		--Carico su UDc Destinazione
		EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
					@Id_Udc					= @Id_Udc,
					@Id_Articolo			= @Id_Articolo,
					@Id_UdcDettaglio		= @Udc_Dettaglio_Dest,
					@Qta_Pezzi_Input		= @Quantita,
					@Id_Causale_Movimento	= 3,
					@FlagControlloQualita	= @FlagControlloQualita,
					@DOPPIO_STEP_QM			= @DOPPIO_STEP_QM,
					@Motivo_CQ				= @MOTIVO_QUALITA,
					@CONTROL_LOT			= @CONTROL_LOT,
					@WBS_CODE				= @WBS_CODE, --SE STO PASSANDO MATERIALE A PROGETTO DEVO ANDARE A PROGETTO
					@Id_Processo			= @Id_Processo,
					@Origine_Log			= @Origine_Log,
					@Id_Utente				= @Id_Utente,
					@Errore					= @Errore OUTPUT

		IF (ISNULL(@Errore, '') <> '')
			THROW 50003 ,@Errore, 1;

		DECLARE @Nuovo_IdUdcDettaglio INT

		SELECT	@Nuovo_IdUdcDettaglio = Id_UdcDettaglio
		FROM	dbo.Udc_Dettaglio
		WHERE	Id_Udc = @Id_Udc
			AND Id_Articolo = @Id_Articolo
			AND ISNULL(WBS_Riferimento,'') = ISNULL(@WBS_CODE,'')

		IF @FlagControlloQualita = 1
		BEGIN
			SET @Errore = 'Attenzione parte della quantità del dettaglio spostato è sottoposta a CONTROLLO QUALITA'''

			IF @Quantita <> @QTA_QUALITA
			BEGIN
				IF EXISTS (SELECT TOP 1 1 FROM Custom.ControlloQualita WHERE CONTROL_LOT = @CONTROL_LOT AND Id_UdcDettaglio = @Nuovo_IdUdcDettaglio)
					UPDATE	Custom.ControlloQualita
					SET		Quantita = @QTA_QUALITA
					WHERE	Id_UdcDettaglio = @Nuovo_IdUdcDettaglio
						AND CONTROL_LOT = @CONTROL_LOT
				ELSE
					INSERT INTO Custom.ControlloQualita
						(Id_UdcDettaglio,MotivoQualita,Quantita, Doppio_Step_QM, CONTROL_LOT)
					VALUES
						(@Nuovo_IdUdcDettaglio,@MOTIVO_QUALITA,@QTA_QUALITA,@DOPPIO_STEP_QM,@CONTROL_LOT)
			END
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
