SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Output_ScaricaCella]
	@PALLETTYPE					VARCHAR(1) = 'N',
	@Id_Partizione				INT,
	@Id_Partizione_Destinazione	INT,
	@Id_Opzione INT = 1,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),	
	@Origine_Log				VARCHAR(25),	
	@Id_Utente					VARCHAR(16),		
	@SavePoint					VARCHAR(32) = '',
	@Errore						VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30);
	DECLARE @TranCount				INT;
	DECLARE @Return					INT;

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId);
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT;
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Id_Udc	INT, 
				@IdTipoUdc varchar(1);

		SET @IdTipoUdc = CASE WHEN @Id_Opzione = 1 THEN '1'
							  WHEN @Id_Opzione = 2 THEN '4'
						 END;
		-- Inserimento del codice;
		EXEC @Return = sp_Insert_Crea_Udc
						@Id_Tipo_Udc   = @IdTipoUdc,
						@Id_Partizione = @Id_Partizione,
						@Id_Udc        = @Id_Udc OUTPUT,
						@Id_Processo   = @Id_Processo,
						@Origine_Log   = @Origine_Log,
						@Id_Utente     = @Id_Utente,
						@Errore        = @Errore OUTPUT;

		IF @Return <> 0
			RAISERROR(@Errore, 12, 1)

		--Controllo se la partizione 
		DECLARE	@IdTipoPartizione varchar(2)
		SELECT	@IdTipoPartizione = ID_TIPO_PARTIZIONE
		FROM	Partizioni
		WHERE	ID_PARTIZIONE = @Id_Partizione

		--Se eseguo lo svuota locazione da magazzino do la possibilità di scegliere la quota deposito
		IF @IdTipoPartizione = 'MA'
		BEGIN		
			--Inserisco l'evento per determinare la quota di deposito
			DECLARE @Action XML =CONCAT(
			'<StoredProcedure ProcedureKey="svuotaLocazioneMagazzino">
				<ActionParameter>
				<Parameter>
					<ParameterName>Id_Udc</ParameterName>
					<ParameterValue>',@Id_Udc,'</ParameterValue>
				</Parameter>
				<Parameter>
					<ParameterName>Id_Partizione_Destinazione</ParameterName>
					<ParameterValue>',@Id_Partizione_Destinazione,'</ParameterValue>
				</Parameter>
				</ActionParameter>
			</StoredProcedure>');
			
			EXEC [dbo].[sp_Insert_Eventi] 
				 @Id_Tipo_Evento = 28 
				 --Lo setto per ora in baia di picking
				,@Id_Partizione = 3101
				,@Id_Tipo_Messaggio = '1100'
				,@XmlMessage = @Action
				,@Id_Processo = @Id_Processo
				,@Origine_Log = @Origine_Log
				,@Id_Utente = @Id_Utente
				,@Errore = @Errore OUTPUT
		END
		ELSE
		BEGIN
			EXEC @Return = sp_Insert_CreaMissioni
							@Id_Udc                     = @Id_Udc,
							@Id_Tipo_Missione           = 'OUT',
							@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
							@Priorita                   = 5,
							@Id_Processo                = @Id_Processo,
							@Origine_Log                = @Origine_Log,
							@Id_Utente                  = @Id_Utente,
							@Errore                     = @Errore OUTPUT;

			IF @Return <> 0 RAISERROR(@Errore,12,1)
		END
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
			
			EXEC sp_Insert_Log
					@Id_Processo     = @Id_Processo,
					@Origine_Log     = @Origine_Log,
					@Proprieta_Log   = @Nome_StoredProcedure,
					@Id_Utente       = @Id_Utente,
					@Id_Tipo_Log     = 4,
					@Id_Tipo_Allerta = 0,
					@Messaggio       = @Errore,
					@Errore          = @Errore OUTPUT
			
			-- Return 0 se la procedura è andata in errore;
			RETURN 1
		END ELSE THROW
	END CATCH
END



DELETE FROM Eventi where Id_Partizione = 3403 and Id_Tipo_Evento = 28
GO
