SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Select_Messaggi]
 @Id_Tipo_Direzione_Messaggio varchar(1)
,@Id_Tipo_Stato_Messaggio int
,@Id_Plc int = 1		
-- Parametri Standard;
,@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(16)		
,@SavePoint			Varchar(32) = ''
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	SET LOCK_TIMEOUT 5000

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		SELECT TOP 1 M.ID_MESSAGGIO,
					M.MESSAGGIO,
					PLC.RemoteIp
		FROM	MESSAGGI_INVIATI M
				INNER JOIN PLC ON PLC.ID_PLC = M.ID_PLC
		WHERE	ISNULL(@Id_Plc, M.ID_PLC) = M.ID_PLC 
				AND ID_TIPO_STATO_MESSAGGIO IN (1,2)
				AND M.ID_PLC = 1
				ORDER BY id_tipo_stato_messaggio DESC, Id_Messaggio ASC
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
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
		END
		-- Return 0 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END


GO
