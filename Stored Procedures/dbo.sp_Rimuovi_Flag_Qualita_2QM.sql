SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROC [dbo].[sp_Rimuovi_Flag_Qualita_2QM]
	@Id_Evento					INT,
	@Id_UdcDettaglio			INT,
	@FlagControlloQualita		INT,
	@CONTROL_LOT				VARCHAR(40)	= NULL,
	--RAPPRESENTA LA QUANTITA CONFORME
	@QuantitaConforme			NUMERIC(10,2) = 0,
	@QtaNonConforme				NUMERIC(10,2) = 0,
	--SE ARRIVO DA UDC_DETTAGLIO
	@MotivoNonConformita		VARCHAR(500) = NULL,
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
	SET @Nome_StoredProcedure	= OBJECT_NAME(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT;

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @Id_Udc						INT
		DECLARE @MotivoQualita				VARCHAR(20) = NULL
		DECLARE @Quantita_Pezzi				NUMERIC(10,2)
		DECLARE @Id_Articolo				INT

		SELECT	@Id_Udc				= UP.Id_Udc,
				@Quantita_Pezzi		= CQ.Quantita,
				@MotivoQualita		= CQ.MotivoQualita,
				@Id_Articolo		= UD.Id_Articolo
		FROM	dbo.Udc_Dettaglio				UD
		JOIN	dbo.Udc_Posizione				UP
		ON		UD.Id_Udc = UP.Id_Udc
		JOIN	Custom.ControlloQualita			CQ
		ON		CQ.Id_UdcDettaglio = UD.Id_UdcDettaglio
		WHERE	UD.Id_UdcDettaglio = @Id_UdcDettaglio
			AND ISNULL(CQ.CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,'')
            
		IF @Id_Udc IS NULL
			THROW 50001, 'ERRORE NELLA SELEZIONE DELL''UDC. UDC NON IN CONTROLLO QUALITA''', 1;

		DECLARE @Qta_Originale NUMERIC(10,2) = 0
		IF @FlagControlloQualita = 1
		BEGIN
			SELECT	@Qta_Originale = SUM(QUANTITY)
			FROM	l3integration.Quality_Changes
			WHERE	Id_Articolo = @Id_Articolo
				AND CONTROL_LOT = @CONTROL_LOT
				AND STAT_QUAL_NEW = 'BLOC'

			IF @Qta_Originale < @QtaNonConforme
				THROW 50009, 'IMPOSSIBILE BLOCCARE PIU'' QUANTITA'' DI QUELLA PREVISTA',1

			SET @Qta_Originale -= @QtaNonConforme
			IF @Qta_Originale > 0
				UPDATE	l3integration.Quality_Changes
				SET		QUANTITY = @Qta_Originale
				WHERE	Id_Articolo = @Id_Articolo
					AND CONTROL_LOT = @CONTROL_LOT
					AND STAT_QUAL_NEW = 'BLOC'
			ELSE
				DELETE 	l3integration.Quality_Changes
				WHERE	Id_Articolo = @Id_Articolo
					AND CONTROL_LOT = @CONTROL_LOT
					AND STAT_QUAL_NEW = 'BLOC'
		END
		ELSE
		BEGIN
			SELECT	@Qta_Originale = SUM(QUANTITY)
			FROM	l3integration.Quality_Changes
			WHERE	Id_Articolo = @Id_Articolo
				AND CONTROL_LOT = @CONTROL_LOT
				AND STAT_QUAL_NEW = 'DISP'

			IF @Qta_Originale < @QuantitaConforme
				THROW 50009, 'IMPOSSIBILE SBLOCCARE PIU'' QUANTITA'' DI QUELLA PREVISTA',1

			SET @Qta_Originale -= @QuantitaConforme
			IF @Qta_Originale > 0
				UPDATE	l3integration.Quality_Changes
				SET		QUANTITY = @Qta_Originale
				WHERE	Id_Articolo = @Id_Articolo
					AND CONTROL_LOT = @CONTROL_LOT
					AND STAT_QUAL_NEW = 'DISP'
			ELSE
				DELETE 	l3integration.Quality_Changes
				WHERE	Id_Articolo = @Id_Articolo
					AND CONTROL_LOT = @CONTROL_LOT
					AND STAT_QUAL_NEW = 'DISP'
		END

		EXEC dbo.sp_Rimuovi_Flag_Qualita
				@Id_UdcDettaglio		= @Id_UdcDettaglio,
				@FlagControlloQualita	= 1,
				@MotivoQualita			= @MotivoQualita,
				@CONTROL_LOT			= @CONTROL_LOT,
				@Quantita_Pezzi			= @Quantita_Pezzi,
				@QuantitaConforme		= @QuantitaConforme,
				@QtaNonConforme			= @QtaNonConforme,
				@MotivoNonConformita	= @MotivoNonConformita,
				@id_partizione_evento	= 3701,
				@DA_SAP					= 1,
				@Id_Processo			= @Id_Processo,
				@Origine_Log			= @Origine_Log,
				@Id_Utente				= @Id_Utente,
				@Errore					= @Errore		OUTPUT
		
		IF @FlagControlloQualita = 0
		BEGIN
			IF NOT EXISTS
			(
				SELECT	TOP 1 1
				FROM	AwmConfig.vUdcDettaglioConforme_2QM
				WHERE	CONTROL_LOT = @CONTROL_LOT
					AND ID_ARTICOLO = @Id_Articolo
			)
				DELETE	dbo.Eventi
				WHERE	Id_Evento = @Id_Evento
		END
		ELSE
		BEGIN
			IF NOT EXISTS
			(
				SELECT	TOP 1 1
				FROM	AwmConfig.vUdcDettaglioNonConforme_2QM
				WHERE	CONTROL_LOT = @CONTROL_LOT
					AND ID_ARTICOLO = @Id_Articolo
			)
				DELETE	dbo.Eventi
				WHERE	Id_Evento = @Id_Evento
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
