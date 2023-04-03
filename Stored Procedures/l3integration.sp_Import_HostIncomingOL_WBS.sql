SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [l3integration].[sp_Import_HostIncomingOL_WBS]
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
	--ORDINI DI ENTRATA MERCE
	BEGIN TRY	
		-- Dichiarazioni Variabili;

		-- Inserimento del codice;		
		DECLARE @Id_Testata			INT
		DECLARE @Prg_Msg			INT
		DECLARE @Load_Order_Id		VARCHAR(40)
		DECLARE @Load_Order_Type	VARCHAR(4)
		DECLARE @Log_Info			VARCHAR(MAX)

		--Carico le testate di ordini in entrata da elaborare ordinate dal primo inserito
		DECLARE CursoreTestata CURSOR LOCAL FAST_FORWARD FOR
			SELECT	PRG_MSG,
					LOAD_ORDER_ID,
					LOAD_ORDER_TYPE
			FROM	L3INTEGRATION.dbo.HOST_INCOMING_ORDERS
			WHERE	STATUS = 0
				AND LOAD_ORDER_TYPE IN ('NWBS','CWBS','DWBS')
			ORDER
				BY	PRG_MSG ASC

		--Scorro le testate
		OPEN CursoreTestata
		FETCH NEXT FROM CursoreTestata INTO
			@Prg_Msg,
			@Load_Order_Id,
			@Load_Order_Type
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				IF EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.CambioCommessaWBS
								WHERE	Load_Order_Id = @Load_Order_Id
									AND Load_Order_Type = @Load_Order_Type
							)
					THROW 50009, 'RECORD DUPLICATO',1

				--Aggiorno stato record della testata  di scambio
				UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_ORDERS
				SET		STATUS = 1,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg
			END TRY
			BEGIN CATCH
				UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_ORDERS
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG = @Prg_Msg

				SET @Log_Info = CONCAT('ERRORE NEL PROCESSARE RECORD INCOMING ORDERS PRG_MSG: ', @Prg_Msg,' LOAD ORDER ID: ', @Load_Order_Id, ' LOAD ORDER TYPE : ', @Load_Order_Type, '  MOTIVO: ' , ERROR_MESSAGE())
				EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 4,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @Log_Info,
						@Errore				= @Errore OUTPUT;
			END CATCH
		
			FETCH NEXT FROM CursoreTestata INTO
				@Prg_Msg,
				@Load_Order_Id,
				@Load_Order_Type
		END

		CLOSE CursoreTestata
		DEALLOCATE CursoreTestata

		SET @Load_Order_Id = NULL
		SET @Load_Order_Type = NULL

		DECLARE @Prg_Msg_S				INT
		DECLARE @Prg_Msg_D				INT
		DECLARE @Load_Line_Id			INT
		DECLARE @WBS_Sorgente			VARCHAR(24)
		DECLARE @WBS_Destinazione		VARCHAR(24)
		DECLARE @Notes_Sorgente			VARCHAR(MAX)
		DECLARE @Notes_Destinazione		VARCHAR(MAX)
		DECLARE @Id_Articolo			INT
		DECLARE @Qta_Pezzi				NUMERIC(10,2)

		--CWBS CON DUE RIGHE UNA CON NOTES 'WBS di destinazione'
		--NWBS ASSEGNA LA NUOVA WBS
		--DWBS LIBERA LE UDC DALLA WBS
		DECLARE CursoreRighe CURSOR LOCAL FAST_FORWARD FOR
			SELECT	HIL_S.PRG_MSG,
					HIL_D.PRG_MSG,
					HIL_S.LOAD_LINE_ID,
					HIL_S.LOAD_ORDER_ID,
					HIL_S.LOAD_ORDER_TYPE,
					CASE
						WHEN HIL_D.NOTES = 'WBS di destinazione' THEN HIL_S.REF_NUMBER
						ELSE HIL_D.REF_NUMBER
					END	SORGENTE,
					CASE
						WHEN HIL_D.NOTES = 'WBS di destinazione' THEN HIL_D.REF_NUMBER
						ELSE HIL_S.REF_NUMBER
					END	DESTINAZIONE,
					CASE
						WHEN HIL_D.NOTES = 'WBS di destinazione' THEN HIL_S.NOTES
						ELSE HIL_D.NOTES
					END	SORGENTE_NOTE,
					CASE
						WHEN HIL_D.NOTES = 'WBS di destinazione' THEN HIL_D.NOTES
						ELSE HIL_S.NOTES
					END	DESTINAZIONE_NOTE,
					A.Id_Articolo,
					HIL_S.QUANTITY
			FROM	l3integration.dbo.HOST_INCOMING_LINES	HIL_S
			JOIN	Articoli								A
			ON		A.Codice = HIL_S.ITEM_CODE
			CROSS
			APPLY	l3integration.dbo.HOST_INCOMING_LINES	HIL_D
			WHERE	HIL_S.STATUS = 0 --ENTRAMBI NON PROCESSATI
				AND HIL_D.STATUS = 0 --ENTRAMBI NON PROCESSATI
				AND HIL_S.LOAD_ORDER_TYPE IN ('CWBS','NWBS','DWBS')
				AND HIL_S.LOAD_ORDER_TYPE = HIL_D.LOAD_ORDER_TYPE
				AND HIL_D.PRG_MSG = HIL_S.PRG_MSG + 1
				AND HIL_D.QUANTITY = HIL_S.QUANTITY

		OPEN CursoreRighe
		FETCH NEXT FROM CursoreRighe INTO
			@Prg_Msg_S,
			@Prg_Msg_D,
			@Load_Line_Id,
			@Load_Order_Id,
			@Load_Order_Type,
			@WBS_Sorgente,
			@WBS_Destinazione,
			@Notes_Sorgente,
			@Notes_Destinazione,
			@Id_Articolo,
			@Qta_Pezzi

		WHILE @@FETCH_STATUS = 0
		BEGIN
			BEGIN TRY
				IF EXISTS	(
								SELECT	TOP 1 1
								FROM	Custom.CambioCommessaWBS
								WHERE	Load_Order_Id = @Load_Order_Id
									AND Load_Order_Type = @Load_Order_Type
							)
					THROW 50009,'RECORD DUPLICATO.',1

				INSERT INTO Custom.CambioCommessaWBS
					(Load_Order_Id,	Load_Order_Type, Id_Articolo, WBS_Partenza,WBS_Destinazione,
						Qta_Pezzi, Id_Stato_Lista,DataOra_Creazione, DataOra_UltimaModifica)
				VALUES
					(@Load_Order_Id, @Load_Order_Type, @Id_Articolo, @WBS_Sorgente, @WBS_Destinazione,
						@Qta_Pezzi, 1, GETDATE(),GETDATE())

				--Aggiorno stato record nella tabella di scambio
				UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_LINES
				SET		STATUS = 1,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG IN (@Prg_Msg_D, @Prg_Msg_S)
			END TRY
			BEGIN CATCH
				UPDATE	L3INTEGRATION.dbo.HOST_INCOMING_LINES
				SET		STATUS = 2,
						DT_ELAB = GETDATE()
				WHERE	PRG_MSG IN (@Prg_Msg_D, @Prg_Msg_S)

				select @Prg_Msg_D, @Prg_Msg_S

				SET @Log_Info = CONCAT('ERRORE NEL PROCESSARE RECORD INCOMING LINES PRG_MSG: ', @Prg_Msg_D,' E ',@Prg_Msg_D,' LOAD ORDER ID: ', @Load_Order_Id, ' LOAD ORDER TYPE : ', @Load_Order_Type, '  MOTIVO: ' , ERROR_MESSAGE())
				EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @Log_Info,
							@Errore				= @Errore			OUTPUT
			END CATCH

			FETCH NEXT FROM CursoreRighe INTO
				@Prg_Msg_S,
				@Prg_Msg_D,
				@Load_Line_Id,
				@Load_Order_Id,
				@Load_Order_Type,
				@WBS_Sorgente,
				@WBS_Destinazione,
				@Notes_Sorgente,
				@Notes_Destinazione,
				@Id_Articolo,
				@Qta_Pezzi
		END

		CLOSE CursoreRighe
		DEALLOCATE CursoreRighe

		-- Fine del codice
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
