SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Insert_Crea_Udc]
	@Codice_Udc			VARCHAR(50) = NULL,
	@Id_Tipo_Udc		VARCHAR(1)	= 'N',
	@Id_Partizione		INT			= NULL,
	@Id_Udc				INT						OUTPUT,
	@Id_Gruppo_Lista	INT			= NULL,
	@Gruppo_Udc			INT			= NULL,
	@Udc_Attiva			BIT			= NULL,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),
	@Errore				VARCHAR(500)			OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Dichiarazioni Variabili;

		-- Creo la Udc In Udc_Testata.
		INSERT INTO Udc_Testata
			(Codice_Udc,Id_Tipo_Udc,Id_Gruppo_Lista,Gruppo_Udc,Udc_Attiva,Xml_Param)
		VALUES
			(@Codice_Udc,@Id_Tipo_Udc,@Id_Gruppo_Lista,@Gruppo_Udc,@Udc_Attiva,'<Parametri><Note>' + ISNULL(@Codice_Udc,'Note') + '</Note></Parametri>')

		-- Recupero l'identità Id_Udc per generare la riga di posizione.
		SELECT @Id_Udc = SCOPE_IDENTITY()

		-- Inserimento del codice;
		IF @Id_Partizione IS NOT NULL
		BEGIN
			IF	(
					SELECT	COUNT(0)
					FROM	Udc_Posizione
					WHERE	Id_Partizione = @Id_Partizione
				)
				>=
				(
					SELECT	CAPIENZA
					FROM	Partizioni
					WHERE	ID_PARTIZIONE = @Id_Partizione
				)
				THROW 50001,'CAPIENZA',1

			INSERT INTO Udc_Posizione
				(Id_Udc, Id_Partizione)
			VALUES
				(@Id_Udc,@Id_Partizione)
		END

		IF @Codice_Udc IS NULL
			UPDATE	Udc_Testata
			SET		Codice_Udc = @Id_Udc
			WHERE	Id_Udc = @Id_Udc

		-- Reset del campo Udc_Attiva. (31/03/2008 U.V.)
		IF @Udc_Attiva = 1
			UPDATE	Udc_Testata
			SET		Udc_Attiva = 0
			WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista
				AND Gruppo_Udc = @Gruppo_Udc
				AND Id_Udc <> @Id_Udc

		IF @Codice_Udc IS NOT NULL
			UPDATE	Custom.AnagraficaBancali
			SET		Stato = 2
			WHERE	Codice_Barcode = @Codice_Udc

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
				
			-- Return 0 se la procedura è andata in errore;
			RETURN 1
		END ELSE THROW
	END CATCH
END
GO
