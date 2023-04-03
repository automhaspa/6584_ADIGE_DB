SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [AwmConfigConfig].[sp_addActionParameter]
	--Parametri
	@entityTypeName varchar(50),
	@ProcedureKey varchar(50),
	@ParameterName varchar(200),
	@ParameterSource varchar(50),
	@ParameterValue varchar(60),
	@DisplayOrder int = null,
	@ResourceName varchar(max) = NULL,
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(16),
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
		-- Dichiarazioni Variabili;
		DECLARE @IsWebService	bit = 0;
		DECLARE	@hash			varchar(250);

		SELECT	@hash = hash
		FROM	AWMCONFIG.entityType
		WHERE	entityTypeName = @entityTypeName
		

		IF(LEN(@hash) >0 AND LEN(@ProcedureKey) > 0 AND LEN(@ParameterName) > 0 AND LEN(@ParameterSource) > 0 AND LEN(@ParameterValue) > 0)
			BEGIN
				INSERT AwmConfig.ActionParameter
				(
					hash,
					ProcedureKey,
					ParameterName,
					ParameterSource,
					ParameterValue,
					DisplayOrder,
					resourceName
				)
				VALUES
				(
					@hash,
					@ProcedureKey,
					@ParameterName,
					@ParameterSource,
					@ParameterValue,
					@DisplayOrder,
					@ResourceName
				)
			END
		ELSE
			THROW 51000, 'I campi del widget non sono stati valorizzati', 1;
		-- Fine del codice;

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
