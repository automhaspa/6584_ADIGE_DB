SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

--SET QUOTED_IDENTIFIER ON|OFF
--SET ANSI_NULLS ON|OFF
--GO
CREATE PROCEDURE [dbo].[sp_SetGeneralParameter]

     @Id_Parametro NCHAR(50)
	,@Valore VARCHAR(150) = NULL
	-- Parametri Standard;
	,@Id_Processo		VARCHAR(30)	
	,@Origine_Log		VARCHAR(25)	
	,@Id_Utente			VARCHAR(32)		
	,@Errore			VARCHAR(500) OUTPUT

-- WITH ENCRYPTION, RECOMPILE, EXECUTE AS CALLER|SELF|OWNER| 'user_name'
AS
BEGIN
	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @cblnTransazione Bit
	DECLARE @Return Int
	DECLARE @ErrLog Varchar(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 SET @cblnTransazione = 1 
	IF (@cblnTransazione = 1) BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;

		-- Controllo che il parametro esista
		IF NOT EXISTS (SELECT 1 FROM dbo.Parametri_Generali AS pg WHERE pg.Id_Parametro = @Id_Parametro)
		BEGIN
			;THROW 51000, 'Non esiste parametro con quel nome', 1;   
		END

		-- Controllo che il valore esista oppure sia un boolean
		IF @Valore IS NULL AND 
		NOT EXISTS (SELECT 1 FROM dbo.Parametri_Generali AS pg WHERE pg.Id_Parametro = @Id_Parametro AND pg.Valore IN ('true', 'false','1','0'))
		BEGIN
    			;THROW 51000, 'Non è stato specificato un valore e non è un boolean', 1;   
		END
		ELSE IF @Valore IS NULL
		BEGIN
			-- Caclolo il valore del boolean
			SELECT @Valore = 
			CASE 
				WHEN pg.Valore IN ('true', '1') THEN '0'
				ELSE '1'
			END
			FROM dbo.Parametri_Generali AS pg
			WHERE pg.Id_Parametro = @Id_Parametro
		END	

		UPDATE dbo.Parametri_Generali
		SET Valore = @Valore
		WHERE Id_Parametro = @Id_Parametro
	
		IF @cblnTransazione = 1 COMMIT TRANSACTION
		-- Return 0 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @cblnTransazione = 1
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
			END
		-- Return 1 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END

GO
