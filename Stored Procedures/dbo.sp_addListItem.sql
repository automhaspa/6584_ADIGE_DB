SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_addListItem]
@Id_Gruppo_Lista INT = NULL
,@Id_Lista INT = NULL
,@Id_Articolo INT = NULL
,@Codice_Articolo VARCHAR(50) = NULL
,@Qty NUMERIC(18,4)
,@Lotto VARCHAR(20) = NULL
-- Parametri Standard;
,@Id_Processo		VARCHAR(30)	
,@Origine_Log		VARCHAR(25)	
,@Id_Utente			VARCHAR(32)		
,@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	-- SET LOCK_TIMEOUT

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	DECLARE @ErrLog VARCHAR(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = OBJECT_NAME(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Id_Stato_Lista INT
		DECLARE @Unita_Misura VARCHAR(3)
		-- Inserimento del codice;
		-- SETTO IL VALORE DI DEFAULT DEL LOTTO IN CASO VENGA PASSATO A NULL
		SET @Lotto = ISNULL(@Lotto,'')

		-- CONTROLLO CHE LA @QTY INSERITA SIA CORRETTA ( > 0 )
		IF(ISNULL(@Qty,0) <= 0 )
			RAISERROR('SpEx_QuantitaErrata',12,1)


		-- SE L'ID_LISTA IN INGRESSO E' NULL CONTROLLO CHE CI SIA ALMENO IL GRUPPO LISTA VALORIZZATO. SE NON C'E' NEANCHE QUELLO ALLORA GENERO UN'ECCEZIONE.
		IF(ISNULL(@Id_Lista,-1) = -1 AND @Id_Gruppo_Lista IS NOT NULL)
			SELECT @Id_Lista = Id_Lista FROM dbo.Liste_Testata WHERE Id_Gruppo_Lista = @Id_Gruppo_Lista

		IF(ISNULL(@Id_Lista,-1) = -1)
			RAISERROR('SpEx_ListNotFound',12,1)


		-- SE L'ID_ARTICOLO IN INGRESSO E' NULL CONTROLLO CHE CI SIA IL CODICE ARTICOLO VALORIZZATO. SE NON C'E' NEANCHE QUELLO GENERO UN ECCEZIONE.
		IF(ISNULL(@Id_Articolo,-1) = -1 AND @Codice_Articolo IS NOT NULL)
			SELECT	@Id_Articolo = Id_Articolo
			FROM	dbo.Articoli
			WHERE	Codice = @Codice_Articolo

		IF(ISNULL(@Id_Articolo,-1) = -1)
			RAISERROR('SpEx_ArticoloNonTrovato',12,1)

		-- PRENDO L'UNITA' DI MISURA DALLA TABELLA ARTICOLI PER L'ID_ARTICOLO PASSATO
		SELECT	@Unita_Misura = Unita_Misura
		FROM	dbo.Articoli
		WHERE	Id_Articolo = @Id_Articolo

		--	CONTROLLO CHE LA LISTA SIA IN STATO 'NUOVO'. SE E' UN UN QUALSIASI ALTRO STATO GENERO UN ERRORE.
		SELECT	@Id_Stato_Lista = Id_Stato_Lista
		FROM	dbo.Liste_Testata
		WHERE	Id_Lista = @Id_Lista

		IF(@Id_Stato_Lista <> 1)
			RAISERROR('SpEx_ListNotSuitable',12,1)

		-- FACCIO L'INSERT DELLA RIGA NELLA LISTE_DETTAGLIO
		INSERT INTO dbo.Liste_Dettaglio (Id_Lista,Id_Articolo,Id_Stato_Articolo,Qta_Lista,Id_Udc,Id_Tipo_Udc,Lotto)
		VALUES
		(@Id_Lista,@Id_Articolo,1,@Qty,NULL,NULL,@Lotto)

		-- PRENDO L'IDENTITY DELLA RIGA APPENA INSERITA
		DECLARE @ID_DETTAGLIO INT
		SELECT @ID_DETTAGLIO = SCOPE_IDENTITY()

		-- FACCIO L'INSERT DELLA RIGA NELLA LISTA_USCITA_DETTAGLIO
		INSERT INTO dbo.Lista_Uscita_Dettaglio (Id_Dettaglio,Qta_Prelevata,HORRNRIG,HORRIDCOMR,UM,Lotto,Customer,DeliveryType)
		VALUES (@ID_DETTAGLIO,0,NULL,NULL,@Unita_Misura,@Lotto,NULL,NULL)
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 0 se tutto è andato a buon fine;
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
			
			-- Return 1 se la procedura è andata in errore;
			 RETURN 1
		END ELSE THROW
	END CATCH
END

GO
