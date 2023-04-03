SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Assegna_FlagCq_Articolo]
	@Id_Articolo		INT				= NULL,
	@MotivoQualita		VARCHAR(MAX)	= NULL,
	@Id_Udc				INT				= NULL,
	@Qta_Pezzi			NUMERIC(10,2)	= NULL,
	@Id_UdcDettaglio	INT				= NULL,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),
	@Errore				VARCHAR(500) OUTPUT
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
		DECLARE @Id_UdcDettaglio_S	INT
		DECLARE @WBS_CODE			VARCHAR(24)
		DECLARE @QTA_PEZZI_INIZIALE	NUMERIC(10,4) = @Qta_Pezzi

		IF	@Id_UdcDettaglio IS NULL
			AND
			NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Udc_Dettaglio
							WHERE	Id_Articolo = @Id_Articolo
						)
			THROW 50001, 'ARTICOLO NON PRESENTE SU ALCUNA UDC', 1

		IF @Id_Udc IS NULL
		BEGIN
			DECLARE Cursore_CQ CURSOR LOCAL FAST_FORWARD FOR
				SELECT	UD.Id_UdcDettaglio,
						UD.Quantita_Pezzi
				FROM	Udc_Dettaglio			UD
				JOIN	Udc_Posizione			UP
				ON		UP.Id_Udc = UD.Id_Udc
				JOIN	Partizioni				P
				ON		P.ID_PARTIZIONE = UP.Id_Partizione
				LEFT
				JOIN	Custom.ControlloQualita CQ
				ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
				WHERE	Id_Articolo = @Id_Articolo
					AND ISNULL(CQ.Quantita, 0) = 0

			OPEN Cursore_CQ
			FETCH NEXT FROM Cursore_CQ INTO
				@Id_UdcDettaglio_S,
				@Qta_Pezzi

			WHILE @@FETCH_STATUS = 0
			BEGIN
				INSERT INTO Custom.ControlloQualita
					(Id_UdcDettaglio, Quantita, MotivoQualita,CONTROL_LOT, Id_Utente)
				VALUES
					(@Id_UdcDettaglio_S, @Qta_Pezzi, @MotivoQualita,'', UPPER(@Id_Utente))

				--CONSUNTIVAZIONE L3 CON UBL
				EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
								@IdCausaleL3		= 'UBL',
								@IdUdcDettaglio		= @Id_UdcDettaglio_S,
								@IdCausaleMovimento = 3,
								@Quantity			= @Qta_Pezzi,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore			OUTPUT

				IF (ISNULL(@Errore, '') <> '')
					RAISERROR(@Errore, 12, 1)

				FETCH NEXT FROM Cursore_CQ INTO
					@Id_UdcDettaglio_S,
					@Qta_Pezzi
			END

			CLOSE Cursore_CQ
			DEALLOCATE Cursore_CQ
		END
		ELSE
		BEGIN
			DECLARE @CONTROL_LOT VARCHAR(MAX) = ''
			IF @Id_UdcDettaglio IS NOT NULL
			BEGIN
				SELECT	@Id_UdcDettaglio_S = Id_UdcDettaglio,
						@Qta_Pezzi = ISNULL(@Qta_Pezzi,Quantita_Pezzi),
						@WBS_CODE = WBS_Riferimento
				FROM	Udc_Dettaglio
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
			END
			ELSE
				SELECT	@Id_UdcDettaglio_S = UD.Id_UdcDettaglio,
						@Qta_Pezzi = ISNULL(@Qta_Pezzi,UD.Quantita_Pezzi),
						@WBS_CODE = UD.WBS_Riferimento,
						@CONTROL_LOT = UD.CONTROL_LOT
				FROM	Udc_Dettaglio			UD
				JOIN	Udc_Posizione			UP
				ON		UP.Id_Udc = UD.Id_Udc
				JOIN	Partizioni				P
				ON		P.ID_PARTIZIONE = UP.Id_Partizione
				LEFT
				JOIN	Custom.ControlloQualita CQ
				ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
				WHERE	Id_Articolo = @Id_Articolo
					AND UD.Id_Udc = @Id_Udc
					AND CQ.Id_UdcDettaglio IS NULL

			IF @Id_UdcDettaglio_S IS NULL
				THROW 50009, 'Udc non trovata. Verificarne la posizione',1

			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.ControlloQualita
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio_S
								AND ISNULL(CONTROL_LOT,'') = @CONTROL_LOT
						)
				THROW 50009, 'Dettaglio già presente in controllo qualità.',1
		
			IF EXISTS (SELECT TOP 1 1 FROM Custom.ControlloQualita WHERE Id_UdcDettaglio = @Id_UdcDettaglio_S AND CONTROL_LOT <> @CONTROL_LOT)
				AND @QTA_PEZZI_INIZIALE IS NULL
				SELECT	@Qta_Pezzi = @Qta_Pezzi - SUM(QUANTITA)
				FROM	Custom.ControlloQualita
				WHERE	Id_UdcDettaglio = @Id_UdcDettaglio_S
					AND CONTROL_LOT <> @CONTROL_LOT

			INSERT INTO Custom.ControlloQualita
				(Id_UdcDettaglio, Quantita, MotivoQualita,CONTROL_LOT, Id_Utente)
			VALUES
				(@Id_UdcDettaglio_S, @Qta_Pezzi , @MotivoQualita,@CONTROL_LOT,UPPER(@Id_Utente))

			--CONSUNTIVAZIONE L3 CON UBL
			EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
								@IdCausaleL3		= 'UBL',
								@IdUdcDettaglio		= @Id_UdcDettaglio_S,
								@IdCausaleMovimento = 3,
								@WBS_CODE			= @WBS_CODE,
								@Quantity			= @Qta_Pezzi,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore			OUTPUT

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
