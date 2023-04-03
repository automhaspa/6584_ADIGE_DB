SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [dbo].[sp_GestMsg_ItemEmpty]
	@Id_Messaggio	INT,
-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),
	@Errore			VARCHAR(500)	OUTPUT
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
		-- Dichiarazioni Variabili;
		DECLARE @Id_Partizione		INT = 0
		DECLARE @Id_Tipo_Evento		INT = 0
		DECLARE @Id_Evento_Pk		INT = 0
		DECLARE @Id_Udc				INT = 0
		DECLARE @IdEventoRejection	INT = NULL
		DECLARE @Action				XML

		-- Inserimento del codice;
		SELECT	@Id_Partizione = ID_PARTIZIONE
		FROM	Messaggi_Ricevuti
		WHERE	ID_MESSAGGIO = @Id_Messaggio

		SELECT	@Id_Udc = Id_Udc
		FROM	Udc_Posizione		UP
		JOIN	Messaggi_Ricevuti	MR
		ON		MR.ID_PARTIZIONE = UP.Id_Partizione
		WHERE	MR.ID_MESSAGGIO = @Id_Messaggio

		IF @Id_Udc = 0
			THROW 50001, 'ERRORE ID UDC NON DEFINITA DOPO IL GETEMPTY',1

		IF @Id_Partizione = 3203
		BEGIN
			DECLARE @IdEvScaricoCompleto	INT = 0
			DECLARE @IdEventoSpec			INT = 0
			DECLARE @TestataListaKit		INT = 0
			DECLARE @KitId					INT = 0

			SELECT	@TestataListaKit = ISNULL(Id_Testata_Lista, 0),
					@KitId = Kit_Id
			FROM	Custom.OrdineKittingUdc
			WHERE	Stato_Udc_Kit = 4
				AND Id_Udc = @Id_Udc
			
			SELECT	@IdEventoSpec = ISNULL(Id_Evento,0)
			FROM	Eventi
			WHERE	Id_Partizione = @Id_Partizione
				AND Id_Tipo_Stato_Evento = 1
				AND Id_Tipo_Evento = 33

			SELECT	@IdEvScaricoCompleto = ISNULL(Id_Evento,0)
			FROM	Eventi
			WHERE	Id_Partizione = @Id_Partizione
				AND Id_Tipo_Stato_Evento = 1
				AND Id_Tipo_Evento = 35

			IF @TestataListaKit <> 0
			BEGIN
				DECLARE @CodiceUdc varchar(30)
				SELECT	@CodiceUdc = Codice_Udc
				FROM	Udc_Testata
				WHERE	Id_Udc = @Id_Udc

				INSERT INTO [L3INTEGRATION].[dbo].[HOST_OUTGOING_SUMMARY]
						([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[ORDER_ID],[ORDER_TYPE],[DT_EVASIONE],[COMM_PROD],[COMM_SALE],[DES_PREL_CONF],[ITEM_CODE_FIN],[FL_KIT],
							[NR_KIT],[PRIORITY],[PROD_LINE],[LINE_ID],[LINE_ID_ERP],[ITEM_CODE],[PROD_ORDER],[QUANTITY],[ACTUAL_QUANTITY],[FL_VOID],[SUB_ORDER_TYPE],[RAD],
							[PFIN],[DOC_NUMBER],[RETURN_DATE],[NOTES],[SAP_DOC_NUM],[KIT_ID],[ID_UDC],[rspos])
					SELECT  GETDATE(), 0, NULL, UPPER(@Id_Utente), tlp.ORDER_ID, tlp.ORDER_TYPE, ISNULL(tlp.DT_EVASIONE, ' '),
							tlp.COMM_PROD, tlp.COMM_SALE, tlp.DES_PREL_CONF, tlp.ITEM_CODE_FIN, 1, tlp.NR_KIT, tlp.PRIORITY,
							rlp.PROD_LINE, rlp.LINE_ID,rlp.LINE_ID_ERP,  rlp.ITEM_CODE, rlp.PROD_ORDER, rlp.QUANTITY, mpd.Qta_Prelevata,
							0, tlp.SUB_ORDER_TYPE, tlp.RAD, tlp.PFIN, rlp.DOC_NUMBER, rlp.RETURN_DATE, NULL, rlp.SAP_DOC_NUM, @KitId, ut.Codice_Udc,rlp.RSPOS
					FROM	Custom.TestataListePrelievo		tlp
					JOIN	Custom.RigheListePrelievo		rlp
					ON		rlp.Id_Testata = tlp.ID
					JOIN	Udc_Testata						ut
					ON		ut.Id_Udc = @Id_Udc
					JOIN	Missioni_Picking_Dettaglio		mpd
					ON		mpd.Id_Testata_Lista = tlp.ID
						AND mpd.Id_Riga_Lista = rlp.ID
					WHERE	tlp.ID = @TestataListaKit

				INSERT INTO [L3INTEGRATION].[dbo].[HOST_KIT_EXTRACTIONS]
					([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[KIT_ID],[ID_UDC])
				VALUES
					(GETDATE(), 0, NULL, UPPER(@Id_Utente),@KitId, @CodiceUdc)

				EXEC @Return = sp_Delete_EliminaUdc
					@Id_Udc			= @Id_Udc,
					@Id_Processo	= @Id_Processo,
					@Origine_Log	= @Origine_Log,
					@Id_Utente		= @Id_Utente,
					@Errore			= @Errore OUTPUT
			END

			--EVENTO DI PRELIEVO COMPLETO UDC TIPO B
			ELSE IF (@IdEvScaricoCompleto <> 0)
			BEGIN
				DECLARE @Log_message VARCHAR(MAX) = 'NON C''E'' L''AUTENTICAZIONE PER LE LISTE DI PRELIEVO SE LO SCARICO DA QUI'
				EXEC sp_Insert_Log
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Proprieta_Log		= @Nome_StoredProcedure,
						@Id_Utente			= @Id_Utente,
						@Id_Tipo_Log		= 4,
						@Id_Tipo_Allerta	= 0,
						@Messaggio			= @Log_message,
						@Errore				= @Errore			OUTPUT
			END
			--SE E UN EVENTO DI SPECIALIZZAZIONE
			ELSE IF (@IdEventoSpec <> 0)
			BEGIN
				DELETE	Eventi
				WHERE	Id_Tipo_Stato_Evento = 1
					AND Id_Partizione = 3203
				
				--AVVIO L'EVENTO DI SCELTA SE L'UDC E' STATA SPECIALIZZATA COMPLETAMENTE
				SET @Action =CONCAT('<StoredProcedure ProcedureKey="selezionaOpzioniSpecializzazione">
										<ActionParameter>
										<Parameter>
											<ParameterName>Id_Udc</ParameterName>
											<ParameterValue>',@Id_Udc,'</ParameterValue>
										</Parameter>
										</ActionParameter>
									</StoredProcedure>');
									
				EXEC [dbo].[sp_Insert_Eventi]
						 @Id_Tipo_Evento = 45 --SELEZIONE OPZIONE SPECIALIZZAZIONE COMPLETA
						,@Id_Partizione = @Id_Partizione
						,@Id_Tipo_Messaggio = '11001'
						,@XmlMessage = @Action
						,@Id_Processo = @Id_Processo
						,@Origine_Log = @Origine_Log
						,@Id_Utente = @Id_Utente
						,@Errore = @Errore OUTPUT
			END
			ELSE
			BEGIN
				--Elimino tutti gli eventi già presenti sulla baia (Picking Manuale o Picking Lista)
				DELETE	Eventi
				WHERE	Id_Partizione = 3203
					AND Id_Tipo_Stato_Evento = 1

				--Inserisco evento di scarico o elimina Udc
				SET @Action = CONCAT('<StoredProcedure ProcedureKey="selezionaOpzioniUscita">
										<ActionParameter>
										<Parameter>
											<ParameterName>Id_Udc</ParameterName>
											<ParameterValue>',@Id_Udc,'</ParameterValue>
										</Parameter>
										<Parameter>
											<ParameterName>Id_Messaggio</ParameterName>
											<ParameterValue>',@Id_Messaggio,'</ParameterValue>
										</Parameter>
										</ActionParameter>
									</StoredProcedure>')

				EXEC [dbo].[sp_Insert_Eventi]
						@Id_Tipo_Evento = 29 --SELEZIONE OPZIONE USCITA
						,@Id_Partizione = @Id_Partizione
						,@Id_Tipo_Messaggio = '11001'
						,@XmlMessage = @Action
						,@Id_Processo = @Id_Processo
						,@Origine_Log = @Origine_Log
						,@Id_Utente = @Id_Utente
						,@Errore = @Errore OUTPUT
			END
		END
		ELSE --IF @Id_Partizione = 3101
		BEGIN
			IF	NOT (@Id_Partizione = 3101 AND EXISTS (SELECT 1 FROM Missioni WHERE Id_Udc = @Id_Udc AND ISNULL(Xml_Param.value('data(//Codice_Udc)[1]','varchar(50)'),'') <> ''))
				BEGIN
					--DECLARE Cursore CURSOR LOCAL FAST_FORWARD FOR
					--	SELECT	Id_Udc
					--	FROM	Udc_Posizione		UP
					--	JOIN	Messaggi_Ricevuti	MR
					--	ON		MR.ID_PARTIZIONE = UP.Id_Partizione
					--	WHERE	MR.ID_MESSAGGIO = @Id_Messaggio

					--OPEN Cursore
					--FETCH NEXT FROM CURSORE INTO
					--	@ID_UDC

					--WHILE @@FETCH_STATUS = 0
					--BEGIN
					EXEC @Return = sp_Delete_EliminaUdc
							@Id_Udc = @Id_Udc,
							@Id_Processo = @Id_Processo,
							@Origine_Log = @Origine_Log,
							@Id_Utente = @Id_Utente,
							@Errore = @Errore OUTPUT

					--	FETCH NEXT FROM CURSORE INTO
					--		@ID_UDC
					--END

					--CLOSE Cursore
					--DEALLOCATE Cursore
				END
		END

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
			RETURN 1
		END ELSE THROW
	END CATCH
END


GO
