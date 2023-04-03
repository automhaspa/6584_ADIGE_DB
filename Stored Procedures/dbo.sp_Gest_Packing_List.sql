SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Gest_Packing_List]
	@Id_Testata_Lista_Prelievo	INT,
	@Id_Articolo				INT,
	@Quantita					NUMERIC(10,2),
	@Id_Evento_Picking			INT,
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
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		DECLARE @CountUdcPacking				INT = 0
		DECLARE @IdUdcPackingList				INT = 0
		DECLARE @Id_Partizione_Destinazione		INT = 3604
		DECLARE @XmlParam						XML
		DECLARE @Id_Tipo_Evento					INT
		DECLARE @IdUDcDettaglioPacking			INT
		
		SELECT	@Id_Partizione_Destinazione = Id_Partizione
		FROM	Eventi
		WHERE	Id_Evento = @Id_Evento_Picking

		SELECT	@CountUdcPacking = COUNT(plut.Id_Udc_Packing_List)
		FROM	Custom.PackingLists					pl
		JOIN	Custom.PackingLists_UdcTestata		plut
		ON		pl.Id_Packing_List = plut.Id_Packing_List
		WHERE	Id_Testata_Lista_Prelievo = @Id_Testata_Lista_Prelievo
			AND plut.Flag_Completa = 0

		--SE HO SOLO UNA PACKING LIST EFFETTUO IN AUTOMATICO IL PASSAGGIO SU PACKING LIST
		IF @CountUdcPacking = 1
		BEGIN
			SELECT	@IdUdcPackingList = plut.Id_Udc_Packing_List
			FROM	Custom.PackingLists					pl
			JOIN	Custom.PackingLists_UdcTestata		plut
			ON		pl.Id_Packing_List = plut.Id_Packing_List
			WHERE	Id_Testata_Lista_Prelievo = @Id_Testata_Lista_Prelievo
				AND plut.Flag_Completa = 0

			SELECT	@IdUDcDettaglioPacking = Id_UdcDettaglio
			FROM	Udc_Dettaglio
			WHERE	Id_Udc = @IdUdcPackingList
				AND Id_Articolo = @Id_Articolo

			--CARICO MANUALE DELLA MERCE
			EXEC dbo.sp_Update_Aggiorna_Contenuto_Udc
						@Id_Udc					= @IdUdcPackingList,
						@Id_Articolo			= @Id_Articolo,
						@Id_UdcDettaglio		= @IdUDcDettaglioPacking,
						@Qta_Pezzi_Input		= @Quantita,
						@Id_Causale_Movimento	= 3,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore				OUTPUT

			IF (ISNULL(@Errore, '') <> '')
				RAISERROR(@Errore, 12, 1)
		END
		ELSE IF @CountUdcPacking > 1
		BEGIN
			SET @Id_Tipo_Evento = 41

			SET @XmlParam = CONCAT('<Parametri><Id_Testata_Lista_Prelievo>', @Id_Testata_Lista_Prelievo ,'</Id_Testata_Lista_Prelievo><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Quantita>',@Quantita,'</Quantita></Parametri>')
			-- Creazione dell'evento solo se la  missione è terminata,altrimenti do il Confirm.
			EXEC @Return = sp_Insert_Eventi
							@Id_Tipo_Evento		= @Id_Tipo_Evento,
							@Id_Partizione		= @Id_Partizione_Destinazione,
							@Id_Tipo_Messaggio	= 1100,
							@XmlMessage			= @XmlParam,
							@id_evento_padre	= @Id_Evento_Picking,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore OUTPUT
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
select * from Tipo_Eventi
select * from AwmConfig.ActionHeader WHERE hash like '%vEventi%'
SELECT  *FROM AwmConfig.ActionParameter WHERE hash like '%vEventi%'
GO
