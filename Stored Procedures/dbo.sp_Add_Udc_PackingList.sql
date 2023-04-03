SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Add_Udc_PackingList]
	@Id_Packing_List	INT,
	@Codice_Udc			VARCHAR(50),
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
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		DECLARE @IdUdcPackingList		INT
		DECLARE @IdAreaTerraAdiacente	INT
		DECLARE @IdPackingList			INT
		DECLARE @NomePackingList		VARCHAR(30)
		DECLARE @StatoLista				INT
		DECLARE @IDTipoUdc				VARCHAR(1) = '1'

		--l'area a terra in cui è  già presente l'altra UDC
		SELECT	@IdAreaTerraAdiacente = up.Id_Partizione
		FROM	Custom.PackingLists_UdcTestata		plut
		JOIN	Udc_Posizione						up
		ON		up.Id_Udc = plut.Id_Udc_Packing_List
		WHERE	Id_Packing_List = @Id_Packing_List

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

		INSERT INTO Custom.PackingLists_UdcTestata
			(Id_Udc_Packing_List,Id_Packing_List,Flag_Completa)
		VALUES
			(@IdUdcPackingList, @Id_Packing_List, 0)

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
