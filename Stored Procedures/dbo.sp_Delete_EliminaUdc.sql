SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Delete_EliminaUdc]
	@Id_Udc			VARCHAR(MAX),
-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure VARCHAR(30)
	DECLARE @TranCount INT
	DECLARE @Return INT
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = OBJECT_NAME(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @Id_Partizione	INT
		DECLARE @Persistenza	BIT
		DECLARE @Cursore		CURSOR
		DECLARE @Id_Missione	INT
		DECLARE @Pos			INT
		DECLARE @Cursore_Udc	CURSOR
		DECLARE @WkTable		TABLE (Id_Udc INT)
		
		--	Recupero gli steps ke mi rimangono da eseguire.
		IF RIGHT(@Id_Udc,1) <> ';'
			SET @Id_Udc = @Id_Udc + ';'

		WHILE (ISNULL(@Pos,CHARINDEX(';',@Id_Udc)) <> 0) 
		BEGIN
			INSERT INTO @WkTable (Id_Udc)
			VALUES (SUBSTRING(@Id_Udc,1,ISNULL(@Pos,CHARINDEX(';',@Id_Udc)) - 1))

			SET @Id_Udc = SUBSTRING(@Id_Udc,ISNULL(@Pos,CHARINDEX(';',@Id_Udc)) + 1,LEN(@Id_Udc))

			SET @Pos = CHARINDEX(';',@Id_Udc)
		END

		DECLARE Cursore_Udc CURSOR LOCAL STATIC FOR
			SELECT	WkTable.Id_Udc,
					Udc_Posizione.Id_Partizione,
					Tipo_Udc.Persistenza
			FROM	@WkTable WkTable
			JOIN	Udc_Testata
			ON		Udc_Testata.Id_Udc = WkTable.Id_Udc
			JOIN	Tipo_Udc
			ON		Udc_Testata.Id_Tipo_Udc = Tipo_Udc.Id_Tipo_Udc
			LEFT
			JOIN	Udc_Posizione
			ON		Udc_Posizione.Id_Udc = Udc_Testata.Id_Udc

		OPEN Cursore_Udc
		FETCH NEXT FROM Cursore_Udc INTO
			@Id_Udc,
			@Id_Partizione,
			@Persistenza

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Annullamento delle missioni che coinvolgono l'udc cancellata;
			DECLARE Cursore_Missioni CURSOR LOCAL STATIC FOR
				SELECT	Id_Missione
				FROM	Missioni
				WHERE	Id_Stato_Missione IN ('NEW','ELA','ESE')
					AND Id_Udc = @Id_Udc

			OPEN Cursore_Missioni
			FETCH NEXT FROM Cursore_Missioni INTO
				@Id_Missione

			WHILE @@FETCH_STATUS = 0
			BEGIN
				EXEC @Return = sp_Update_Stato_Missioni
							@Id_Missione		= @Id_Missione,
							@Id_Stato_Missione	= 'DEL',
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore		OUTPUT

				IF @Return <> 0
					RAISERROR(@Errore,12,1)

				FETCH NEXT FROM Cursore_Missioni INTO
					@Id_Missione
			END

			CLOSE Cursore_Missioni
			DEALLOCATE Cursore_Missioni

			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Partizioni
							WHERE	ID_PARTIZIONE = @Id_Partizione
								AND ID_TIPO_PARTIZIONE = 'KT'
						)
					AND @Id_Partizione <> 3203
			BEGIN
				DECLARE @TestataListaKit		INT	= 0
				DECLARE @KitId					INT	= 0

				SELECT	@TestataListaKit = ISNULL(Id_Testata_Lista, 0),
						@KitId = Kit_Id
				FROM	Custom.OrdineKittingUdc
				WHERE	Id_Udc = @Id_Udc

				IF @TestataListaKit <> 0
				BEGIN
					DECLARE @CodiceUdc	VARCHAR(30)
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
				END
			END

			--SE L'UDC E' COINVOLTA IN LISTE DI PRELIEVO CHE SONO ANCORA IN CORSO LA CHIUDO E INVIO IL CONSUNTIVO
			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Missioni_Picking_Dettaglio
							WHERE	Id_Udc = @Id_Udc
								AND Id_Stato_Missione IN (1,2,3)
						)
			BEGIN
				DECLARE	@IdRigaLista			INT
				DECLARE	@Quantita				NUMERIC(10,2)
				DECLARE	@IdTestataLista			INT
				DECLARE	@IdUdcDettaglio			INT

				--CICLO TUTTI GLI ARTICOLI IN LISTA SU QUEL UDC
				DECLARE CursoreRighePrelievo CURSOR LOCAL FAST_FORWARD FOR
					SELECT	Id_Testata_Lista,
							Id_Riga_Lista,
							Quantita,
							Id_UdcDettaglio
					FROM	Missioni_Picking_Dettaglio
					WHERE	Id_Udc = @Id_Udc
						AND Id_Stato_Missione IN (1,2,3)

				OPEN CursoreRighePrelievo
				FETCH NEXT FROM CursoreRighePrelievo INTO
					@IdTestataLista,
					@IdRigaLista,
					@Quantita,
					@IdUdcDettaglio

				WHILE @@FETCH_STATUS = 0
				BEGIN
					UPDATE	Missioni_Picking_Dettaglio
					SET		Qta_Prelevata = @Quantita,
							Id_Stato_Missione = 4
					WHERE	Id_Udc = @Id_Udc
						AND Id_Testata_Lista = @IdTestataLista
						AND Id_Riga_Lista = @IdRigaLista

					--GENERO CONSUNTIVO VERSO L3 PER GLI ANNULLAMENTI RIGA DALLO STOCCA UDC
					EXEC [dbo].[sp_Genera_Consuntivo_PrelievoLista]
								@Id_Udc				= @Id_Udc,
								@Id_Testata_Lista	= @IdTestataLista,
								@Id_Riga_Lista		= @IdRigaLista,
								@Qta_Prelevata		= @Quantita,
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Id_Utente			= @Id_Utente,
								@Errore				= @Errore			OUTPUT

						IF ISNULL(@Errore, '') <> ''
							THROW 50100, @Errore, 1

					--PER LO STORICO CUSTOM AGGIORNO PER OGNI UDC DETTAGLIO DELL'UDC CHE STO PER ELIMINARE I DATI SU TESTATA LISTA E RIGA LISTA
					UPDATE	Udc_Dettaglio
					SET		Id_Testata_Lista_Prelievo = @IdTestataLista,
							Id_Riga_Lista_Prelievo = @IdRigaLista,
							Id_Ddt_Reale = NULL,
							Id_Riga_Ddt = NULL,
							Id_Causale_L3 = NULL
					WHERE	Id_UdcDettaglio = @IdUdcDettaglio

					FETCH NEXT FROM CursoreRighePrelievo INTO
						@IdTestataLista,
						@IdRigaLista,
						@Quantita,
						@IdUdcDettaglio
				END

				CLOSE CursoreRighePrelievo
				DEALLOCATE CursoreRighePrelievo
			END

			DELETE	MESSAGGI_PERCORSI
			WHERE	ID_PERCORSO IN (SELECT ID_MISSIONE FROM MISSIONI WHERE ID_UDC = @ID_UDC)

			DELETE	Missioni
			WHERE	ID_UDC = @ID_UDC

			--DEVO CANCELLARE IL DETTAGLIO MA PRIMA GLI DO L'UTENTE PERCHE' NEL TRIGGER LO PERDE
			UPDATE	dbo.Udc_Dettaglio
			SET		Id_Utente_Movimento = @Id_Utente
			WHERE	Id_Udc = @Id_Udc

			DELETE	Udc_Dettaglio
			WHERE	Id_Udc = @Id_Udc
				AND @Persistenza = 0

			-- CAMBIO DELLA POSIZIONE CON L'AREA A TERRA
			IF @Persistenza = 0
				DELETE	dbo.Udc_Posizione
				WHERE	Id_Udc = @Id_Udc
			ELSE
			BEGIN
				DELETE	Udc_Posizione
				WHERE	Id_Udc = @Id_Udc

				SET @Errore = 'AREA A TERRA NON GESTITA.'
			END

			-- Cancellazione dei prelievi attivi sull'Udc;
			DELETE	Missioni_Dettaglio
			WHERE	Id_Udc = @Id_Udc

			-- Cancellazione della testata (solo se il tipo di udc non è persistente);
			DELETE	Udc_Testata
			WHERE	Id_Udc = @Id_Udc
				AND @Persistenza = 0

			-- Chiusura degli eventi.
			DELETE	Eventi
			WHERE	Id_Partizione = @Id_Partizione

			FETCH NEXT FROM Cursore_Udc INTO
				@Id_Udc,
				@Id_Partizione,
				@Persistenza
		END
		
		CLOSE Cursore_Udc
		DEALLOCATE Cursore_Udc
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
		END
		ELSE THROW
	END CATCH
END
GO
