SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Elabora_Eventi]
-- Parametri Standard;
@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(32)		
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	-- SET LOCK_TIMEOUT

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	DECLARE @ErrLog Varchar(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Cur_Eventi CURSOR
		DECLARE @Cur_Id_Evento Int
		DECLARE @Cur_Id_Tipo_Evento Int
		DECLARE @Cur_Id_Partizione Int
		DECLARE @Cur_Id_Tipo_Messaggio Varchar(4)
		DECLARE @Cur_Id_Utente Varchar(16)
		DECLARE @Cur_Id_Processo Varchar(30) 
		DECLARE @Cur_Xml Xml
		DECLARE @Stored_Procedure Varchar(100)
		
		-- Inserimento del codice;
		SET	@Cur_Eventi =  CURSOR FOR		
		SELECT    Eventi.Id_Evento
				, Eventi.Id_Tipo_Evento
				, Eventi.Id_Partizione
				, Eventi.Id_Tipo_Messaggio
				, Eventi.Id_Utente
				, Eventi.Id_Processo
				, Eventi.Xml_Param
		FROM	Eventi WITH (NOLOCK) INNER JOIN Tipo_Eventi WITH(NOLOCK) ON Tipo_Eventi.Id_Tipo_Evento = Eventi.Id_Tipo_Evento
		WHERE	Id_Tipo_Stato_Evento = 1
				AND Tipo_Eventi.Id_Tipo_Gestore_Eventi = 'SQL'
		ORDER BY Id_Evento ASC

		OPEN @Cur_Eventi

		FETCH NEXT FROM @Cur_Eventi INTO
		@Cur_Id_Evento,
		@Cur_Id_Tipo_Evento,
		@Cur_Id_Partizione,
		@Cur_Id_Tipo_Messaggio, 
		@Cur_Id_Utente, 
		@Cur_Id_Processo,  
		@Cur_Xml
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT	@Stored_Procedure = RTRIM(Azione_Evento)
			FROM	Tipo_Eventi WITH(NOLOCK)
			WHERE	Id_Tipo_Evento = @Cur_Id_Tipo_Evento
					
			EXEC @Return = @Stored_Procedure @Cur_Xml,@Cur_Id_Partizione,@Cur_Id_Tipo_Messaggio,@Cur_Id_Processo,@Stored_Procedure,@Cur_Id_Utente,@Errore OUTPUT
			IF @Return = 0 
			BEGIN
				EXEC sp_Update_Stato_Eventi @Id_Evento = @Cur_Id_Evento
											,@Id_Tipo_Stato_Evento = 3
											,@Id_Processo = @Cur_Id_Processo
											,@Origine_Log = @Stored_Procedure
											,@Id_Utente = @Cur_Id_Utente
											,@Errore = @Errore OUTPUT
			END
			ELSE
			BEGIN
				 EXEC sp_Update_Stato_Eventi @Id_Evento = @Cur_Id_Evento
											,@Id_Tipo_Stato_Evento = 8
											,@Id_Processo = @Cur_Id_Processo
											,@Origine_Log = @Stored_Procedure
											,@Id_Utente = @Cur_Id_Utente
											,@Errore = @Errore OUTPUT
			END
			
			FETCH NEXT FROM @Cur_Eventi INTO
			@Cur_Id_Evento,
			@Cur_Id_Tipo_Evento,
			@Cur_Id_Partizione,
			@Cur_Id_Tipo_Messaggio, 
			@Cur_Id_Utente, 
			@Cur_Id_Processo,  
			@Cur_Xml
		END

		CLOSE @Cur_Eventi
		DEALLOCATE @Cur_Eventi
		-- Fine del codice;

		RETURN 0
	END TRY
	BEGIN CATCH
		EXEC sp_Insert_Log	@Id_Processo = @Id_Processo
							,@Origine_Log = @Origine_Log
							,@Proprieta_Log = @Nome_StoredProcedure
							,@Id_Utente = @Id_Utente
							,@Id_Tipo_Log = 4
							,@Id_Tipo_Allerta = 0
							,@Messaggio = @Errore
							,@Errore = @Errore OUTPUT
		RETURN 1
	END CATCH
END

GO
