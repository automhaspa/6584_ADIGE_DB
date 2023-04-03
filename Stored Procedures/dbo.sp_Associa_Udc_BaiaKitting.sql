SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Associa_Udc_BaiaKitting]
	@Id_Partizione		INT,
	@Codice_Udc			VARCHAR(18),
	@Id_Testata_Lista	INT,
	@Id_Evento			INT,
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
		--INSERISCO LA NUOVA UDC SULLA BAIA
		DECLARE @IdTipoUdc	VARCHAR(1) = '1'
		DECLARE @IdNewUdc	INT

		EXEC dbo.sp_Insert_Crea_Udc		
						@Id_Tipo_Udc	= @IdTipoUdc,
						@Codice_Udc		= @Codice_Udc,
						@Id_Partizione	= @Id_Partizione,
						@Id_Udc			= @IdNewUdc			OUTPUT,
						@Id_Processo	= @Id_Processo,
						@Origine_Log	= @Origine_Log,
						@Id_Utente		= @Id_Utente,
						@Errore			= @Errore			OUTPUT

		IF (ISNULL(@Errore, '') <> '')
			RAISERROR(@Errore, 12, 1)

		--Recupero il kit id disponibile per quelli che non sono ancora coinvolti in una missione
		DECLARE @KitId INT
		
		SELECT	@KitId = RLP.KIT_ID
		FROM	Custom.RigheListePrelievo	RLP
		LEFT
		JOIN	Custom.OrdineKittingBaia	OKB
		ON		OKB.KIT_ID = RLP.KIT_ID
		WHERE	Id_Testata = @Id_Testata_Lista
			AND RLP.STATO = 1
			AND OKB.Id_Testata_Lista IS NULL

		IF @KitId IS NULL
			THROW 50001, 'KIT ID ESAURITI PER L''ORDINE, INUTILE ASSOCIARE UNA NUOVA BAIA',1
			
		--Ordine kitting baia in stato  1
		INSERT INTO Custom.OrdineKittingBaia
		VALUES (@Id_Testata_Lista, @Id_Partizione, @KitId)
		
		INSERT INTO Custom.OrdineKittingUdc
		VALUES (@Id_Testata_Lista , @IdNewUdc, @KitId, 1)

		--CONTROLLO CHE SIA FINITA L'ASSEGNAZIONE KIT
		DECLARE @NKitIdLista	INT
		DECLARE @NKitListaBaie	INT

		SELECT	@NKitIdLista = COUNT(DISTINCT KIT_ID)
		FROM	Custom.RigheListePrelievo
		WHERE	Id_Testata = @Id_Testata_Lista

		SELECT	@NKitListaBaie = COUNT(DISTINCT Kit_Id)
		FROM	Custom.OrdineKittingBaia
		WHERE	Id_Testata_Lista = @Id_Testata_Lista
		
		--Chiudo l'evento se mi ha finito di associare tutte l baie 
		IF (@NKitIdLista = @NKitListaBaie)
			DELETE	Eventi
			WHERE	Id_Evento = @Id_Evento

		--Controllo che siano finite le baie da associare
		DECLARE @CountBaieDisp	INT
		SELECT	@CountBaieDisp = COUNT(1)
		FROM	AwmConfig.vBaieKittingDisponibili
		
		IF @CountBaieDisp = 0
			DELETE	Eventi
			WHERE	Id_Evento = @Id_Evento

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
