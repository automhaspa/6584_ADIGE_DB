SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [ConfIniziale].[sp_CreazioneTunnel]
	@ID_SCAFFALE INT,
	@PIANI INT,
	@COLONNE INT,
	@NUMERO_PROFONDITA INT,
	@ALTEZZA INT,
	@LARGHEZZA INT,
	@PROFONDITA INT,
	@PESO INT,
	@ID_TIPO_PARTIZIONE VARCHAR(2) = 'MA',
	@CAPIENZA INT,
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
		DECLARE @Numero_Tunnel Int
		DECLARE @Descrizione_Scaffale Varchar(4)
		DECLARE @Codice_Abbreviato Varchar(4)
		DECLARE @Codice_Abbreviato_SottoComponente CHAR(4)
		DECLARE @Count Int
		DECLARE @COUNT_PARTIZIONI INT
		DECLARE @ID_SOTTOCOMPONENTE INT

		-- Inserimento del codice;
		SELECT	@Descrizione_Scaffale = Descrizione
		FROM	Componenti	
		WHERE	Id_Componente = @ID_SCAFFALE

		SET @Numero_Tunnel = @COLONNE * @PIANI

		INSERT INTO SottoComponenti (Id_Componente,Descrizione,Codice_Abbreviato)
		VALUES (@ID_SCAFFALE,@Descrizione_Scaffale,'0000')

		SELECT @ID_SOTTOCOMPONENTE = SCOPE_IDENTITY()

		INSERT INTO Partizioni (Id_SottoComponente,Descrizione,Codice_Abbreviato,Id_Tipo_Partizione, CAPIENZA)
		VALUES (@Id_SottoComponente,@Descrizione_Scaffale,'0000',@ID_TIPO_PARTIZIONE, @CAPIENZA)


		WHILE ISNULL(@Count,0) < @Numero_Tunnel
		BEGIN

			SET @Count = ISNULL(@Count,0) + 1
			SET @COUNT_PARTIZIONI = 0

			IF @Count <= 9 SET @Codice_Abbreviato = '000' + CONVERT(Varchar,@Count)
			ELSE IF @Count <= 99 SET @Codice_Abbreviato = '00' + CONVERT(Varchar,@Count)
			ELSE IF @Count <= 999 SET @Codice_Abbreviato = '0' + CONVERT(Varchar,@Count)
			ELSE SET @Codice_Abbreviato = CONVERT(VARCHAR,@Count)
		
			INSERT INTO SottoComponenti (Id_Componente,Descrizione,Codice_Abbreviato,PIANO,COLONNA)
			VALUES (@ID_SCAFFALE
					,@Descrizione_Scaffale + '.' + @Codice_Abbreviato
					,@Codice_Abbreviato
					, CEILING(CONVERT(NUMERIC(18, 9), @Codice_Abbreviato) / @COLONNE) 
					, CONVERT(NUMERIC(18, 9), @Codice_Abbreviato) - (CEILING(CONVERT(NUMERIC(18, 9), @Codice_Abbreviato) / @COLONNE) - 1) * @COLONNE)
			SELECT @ID_SOTTOCOMPONENTE = SCOPE_IDENTITY()
			SET @Codice_Abbreviato_SottoComponente = @Codice_Abbreviato

			WHILE ISNULL(@COUNT_PARTIZIONI,0) < @NUMERO_PROFONDITA
			BEGIN
				SET @COUNT_PARTIZIONI = ISNULL(@COUNT_PARTIZIONI,0) + 1
			
				IF @COUNT_PARTIZIONI <= 9 SET @Codice_Abbreviato = '000' + CONVERT(VARCHAR,@COUNT_PARTIZIONI)
				ELSE IF @COUNT_PARTIZIONI <= 99 SET @Codice_Abbreviato = '00' + CONVERT(VARCHAR,@COUNT_PARTIZIONI)
				ELSE IF @COUNT_PARTIZIONI <= 999 SET @Codice_Abbreviato = '0' + CONVERT(VARCHAR,@COUNT_PARTIZIONI)
				ELSE SET @Codice_Abbreviato = CONVERT(VARCHAR,@Count)
			
				INSERT INTO dbo.Partizioni (ID_SOTTOCOMPONENTE,DESCRIZIONE,CODICE_ABBREVIATO,ID_TIPO_PARTIZIONE,CAPIENZA,LOCKED,ALTEZZA,LARGHEZZA,PROFONDITA,PESO,Motivo_Blocco)
				VALUES
				(
					@ID_SOTTOCOMPONENTE,
					@Descrizione_Scaffale + '.' + @Codice_Abbreviato_SottoComponente + '.' + @Codice_Abbreviato,
					@Codice_Abbreviato, 
					@ID_TIPO_PARTIZIONE, 
					@CAPIENZA, 
					0,
					@ALTEZZA,
					@LARGHEZZA,
					@PROFONDITA,
					@PESO,
					NULL
				)
			END
		END
	

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
