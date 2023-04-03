SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Insert_Log]
 @Id_Processo		varchar(30)
,@Origine_Log		varchar(25)
,@Proprieta_Log		varchar(100)
,@Id_Utente			varchar(32)
,@Id_Tipo_Log		int
,@Id_Tipo_Allerta	int
,@SavePoint			Varchar(130) = ''
,@Messaggio			ntext
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	BEGIN TRY
		-- Inserimento della riga di Log.
		IF (@Id_Tipo_Log NOT IN (2) AND @Origine_Log NOT IN ('UDPCLIENT')) --OR ((SELECT Convert(Bit,ISNULL(Valore,1)) FROM Parametri_Generali WHERE Id_Parametro = 'Log_PCM') = 1
		BEGIN
			INSERT INTO [dbo].[Log](Id_Processo,Origine_Log,Proprietà_Log,Id_Utente,Id_Tipo_Log,Id_Tipo_Allerta,Messaggio)
			VALUES (@Id_Processo,@Origine_Log,@Proprieta_Log,@Id_Utente,@Id_Tipo_Log,@Id_Tipo_Allerta,@Messaggio)
		END
	END TRY
	BEGIN CATCH
		-- SELECT ERROR_MESSAGE()
	END CATCH
END
GO
