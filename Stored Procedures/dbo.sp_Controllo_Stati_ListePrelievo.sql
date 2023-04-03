SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Controllo_Stati_ListePrelievo]
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
		DECLARE @START DATETIME = GETDATE()

		-- Dichiarazioni Variabili;
		DECLARE @Id_Testata_Lista		INT
		
		--CURSORE DI CONTROLLO EVASIONE LISTA PER MANCANTI PRELEVATI SUCCESSIVAMENTE --per gli ordini in corso o sospesi o già evasi con Mancanti che potrebbero essere inclusi da ingombranti
		DECLARE CursoreListeAttive CURSOR LOCAL FAST_FORWARD FOR
			--SELECT	ID
			--FROM	Custom.TestataListePrelievo  WITH (NOLOCK)
			--WHERE	Stato IN (2,5) --IN (2,3,5)
			--GROUP
			--	BY	ID
			--FILTRO GIA CHI NON HA RIGHE INEVASE APERTE
			WITH RIGHE_INEVASE AS
			(
				SELECT	RLP.Id_Testata,
						RLP.QUANTITY - ISNULL(MPD.Qta_Prelevata,0)	QTA_Da_Evadere
				FROM	Custom.RigheListePrelievo		RLP
				LEFT
				JOIN	Missioni_Picking_Dettaglio		MPD
				ON		MPD.Id_Riga_Lista = RLP.ID
					AND MPD.Id_Testata_Lista = RLP.Id_Testata
				WHERE	RLP.QUANTITY > ISNULL(MPD.Qta_Prelevata,0)
			)
			SELECT	TLP.ID
			FROM	Custom.TestataListePrelievo		TLP
			LEFT
			JOIN	RIGHE_INEVASE					RI
			ON		RI.Id_Testata = TLP.ID
			WHERE	TLP.Stato IN (2,5)
			GROUP
				BY	TLP.ID
			HAVING  SUM(QTA_DA_EVADERE) = 0

		OPEN CursoreListeAttive
		FETCH NEXT FROM CursoreListeAttive
			INTO @Id_Testata_Lista

		WHILE @@FETCH_STATUS = 0
		BEGIN
			--Controllo lo stato lista
			EXEC [dbo].[sp_Update_Stati_ListePrelievo]
						@Id_Testata_Lista	= @Id_Testata_Lista,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore		OUTPUT

			IF (ISNULL(@Errore, '') <> '')
				THROW 50002, @Errore, 1

			FETCH NEXT FROM CursoreListeAttive INTO
				@Id_Testata_Lista
		END

		CLOSE CursoreListeAttive
		DEALLOCATE CursoreListeAttive

		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())

		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Gestione Liste Prelievi - TEMPO IMPIEGATO ',@TEMPO)
			EXEC dbo.sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= 'Tempistiche',
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 16,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @MSG_LOG,
					@Errore				= @Errore OUTPUT;
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
