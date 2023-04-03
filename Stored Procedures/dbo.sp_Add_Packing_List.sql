SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Add_Packing_List]	
	@Codice_Udc			VARCHAR(50),
	--Id testata lista prelievo 
	@ID					INT,
	@Id_Partizione		INT,
	@Nome_Packing_List	VARCHAR(30) = NULL,
	@ORDER_ID			VARCHAR(10) = NULL,
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
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		DECLARE @IdUdcPackingList		INT
		DECLARE	@IdAreaTerraAdiacente	INT
		DECLARE	@IdPackingList			INT
		DECLARE	@NomePackingList		VARCHAR(30)
		DECLARE	@StatoLista				INT

		SELECT	@StatoLista = Stato,
				@ORDER_ID = ORDER_ID
		FROM	Custom.TestataListePrelievo
		WHERE	ID = @ID
		
		IF (@StatoLista NOT IN (1,2))
			THROW 50001, ' L''ASSOCIAZIONE AD UNA PACKING LIST E'' POSSIBILE SOLO PER LISTE NON EVASE O IN ESECUZIONE',1

		IF EXISTS(SELECT TOP 1 1 FROM Custom.PackingLists WHERE Id_Testata_Lista_Prelievo = @ID)
			THROW 50002, ' E'' POSSIBILE CREARE UNA SOLA PACKING LIST PER LISTA DI PRELIEVO MA CON PIU'' UDC DESTINAZIONE', 1

		DECLARE @IdTipoUdc VARCHAR(1) = '1' --Udc tipo A

		--Creo l'udc packing list nell'area a terra adiacente
		SET @IdAreaTerraAdiacente = CASE
										WHEN @Id_Partizione = 3404 THEN 7737 --5A06.0001.0001
										WHEN @Id_Partizione = 3604 THEN 7738 --5A06.0002.0001
										ELSE 0
									END

		IF @IdAreaTerraAdiacente = 0
			THROW 50006, 'NESSUNA AREA A TERRA ADIACENTE ALLA PARTIZIONE E'' REGISTRATO',1

		--Creo L'Udc
		EXEC dbo.sp_Insert_Crea_Udc
					@Id_Tipo_Udc	= @IDTipoUdc,
					@Id_Partizione	= @IdAreaTerraAdiacente,
					@Id_Udc			= @IdUdcPackingList		OUTPUT,
					@Codice_Udc		= @Codice_Udc,
					@Id_Processo	= @Id_Processo,
					@Origine_Log	= @Origine_Log,
					@Id_Utente		= @Id_Utente,
					@Errore			= @Errore				OUTPUT

		IF (@IdUdcPackingList = 0 OR ISNULL(@Errore, '') <> '')
			THROW 50007, 'IMPOSSIBILE CREARE NUOVA UDC IN AREA A TERRA', 1

		--SE E' NULL lo personalizzo
		IF @Nome_Packing_List IS NULL
			SET @NomePackingList = CONCAT('PACKING LIST ', @ORDER_ID)
		ELSE
			SET @NomePackingList = @Nome_Packing_List

		--Inserisco i record nelle tabelle packing list
		INSERT INTO Custom.PackingLists
			(Id_Testata_Lista_Prelievo, Nome_Packing_List)
		VALUES
			(@ID, @NomePackingList)

		--Associo l'udc alla packing list ancora incompleta
		SET @IdPackingList = SCOPE_IDENTITY()
		INSERT INTO Custom.PackingLists_UdcTestata
			(Id_Udc_Packing_List,Id_Packing_List,Flag_Completa)
		VALUES
			(@IdUdcPackingList, @IdPackingList, 0)

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

SELECT * FROM AwmConfig.Routes WHERE hash LIKE '%pACKING%'




SELECT * FROM Custom.PackingLists
SELECT * FROM Custom.PackingLists_UdcTestata
SELECT * FROM Log ORDER BY DataOra_Log DESC
GO
