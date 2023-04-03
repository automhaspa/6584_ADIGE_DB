SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [l3integration].[sp_Import_HostItems]
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),	
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	-- SET LOCK_TIMEOUT;

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(100);
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
		DECLARE @Id_Articolo_PrgMsg		BIGINT
		DECLARE @Item_Code				VARCHAR(18)
		DECLARE @Des_Item_Code			VARCHAR(80)
		DECLARE @Item_type				VARCHAR(3)
		DECLARE @Udm					VARCHAR(3)
		DECLARE @Fl_Delete				FLOAT
		DECLARE @BOX0AG					VARCHAR(100)
		DECLARE @Msg					VARCHAR(MAX)

		-- Inserimento del codice;
		--Carico gli articoli da elaborare
		DECLARE CursoreArticoli CURSOR LOCAL FAST_FORWARD FOR
			SELECT	PRG_MSG,
					ITEM_CODE,
					DES_ITEM_CODE,
					ITEM_TYPE,
					CASE
						WHEN UDM = 'M' THEN 'MT'
						WHEN UDM = 'L' THEN 'LT'
						ELSE UDM
					END,
					FL_DELETE,
					BOX0AG
			FROM	L3INTEGRATION.dbo.HOST_ITEMS
			WHERE	STATUS = 0
			ORDER
				BY	PRG_MSG

		OPEN CursoreArticoli
		FETCH NEXT FROM CursoreArticoli INTO
				@Id_Articolo_PrgMsg,
				@Item_Code,
				@Des_Item_Code,
				@Item_type,
				@Udm,
				@Fl_Delete,
				@BOX0AG

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
			--Elaboro ogni nuovo messaggio 			
			IF @Fl_Delete = 1
			BEGIN
				--Elimino l'articolo dalla tabella articoli (Il codice e' univoco quindi non vado a cercare l'Id PK)
				IF (EXISTS(SELECT TOP(1) 1 FROM Articoli WHERE Articoli.Codice = @Item_Code))
					DELETE	Articoli
					WHERE	Codice = @Item_Code

				SET XACT_ABORT ON
				INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_ITEMS (ART_OPERAZIONE, ITEM_CODE, DES_ITEM_CODE, UDM) VALUES ('D', @Item_Code, @Des_Item_Code, @Udm)
				SET XACT_ABORT OFF

				UPDATE	L3INTEGRATION.dbo.HOST_ITEMS
				SET		STATUS = 1, DT_ELAB = GETDATE()
				WHERE   PRG_MSG = @Id_Articolo_PrgMsg
			END
			ELSE IF (@Fl_Delete = 0)
			BEGIN					
				--Aggiungo l'articolo alla tabella articoli se non è  già  presente
				IF (NOT EXISTS(SELECT TOP(1) 1 FROM Articoli WHERE Articoli.Codice = @Item_Code))
					INSERT INTO Articoli
						(Codice,Descrizione,Unita_Misura,Classe)
					VALUES (@Item_Code, @Des_Item_Code, @Udm, @Item_type)
				ELSE
					--Se l'articolo è già  presente nel nostro DB effettuo l'update
					UPDATE	Articoli
					SET		Descrizione = @Des_Item_Code,
							Unita_Misura = @Udm,
							Classe = @Item_type
					WHERE	Codice = @Item_Code

				SET XACT_ABORT ON
				INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_ITEMS (ITEM_CODE, DES_ITEM_CODE, UDM) VALUES (@Item_Code, @Des_Item_Code, @Udm)
				SET XACT_ABORT OFF

				UPDATE	L3INTEGRATION.dbo.HOST_ITEMS
				SET		STATUS = 1,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Id_Articolo_PrgMsg
			END
			ELSE
				THROW 51000, 'Valore di Fldelete non conforme', 1
			END TRY
			BEGIN CATCH
				--Se ho eccezioni nell'importazione articolo lo setto in stato 2
				UPDATE	L3INTEGRATION.dbo.HOST_ITEMS
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Id_Articolo_PrgMsg
				
				SET @Msg = CONCAT('ERRORE NEL PROCESSARE RECORD PRG_MSG: ', @Id_Articolo_PrgMsg ,' MOTIVO: ' , ERROR_MESSAGE())
				
				EXEC sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= @Nome_StoredProcedure,
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 4,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @Msg,
					@Errore				= @Errore OUTPUT;
			END CATCH

			FETCH NEXT FROM CursoreArticoli INTO
					@Id_Articolo_PrgMsg,
					@Item_Code,
					@Des_Item_Code,
					@Item_type,
					@Udm,
					@Fl_Delete,
					@BOX0AG;
		END

		CLOSE CursoreArticoli
		DEALLOCATE CursoreArticoli
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
