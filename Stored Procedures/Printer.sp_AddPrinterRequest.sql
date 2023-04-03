SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [Printer].[sp_AddPrinterRequest]
	@Id_Evento						INT				= NULL,
	@Id_Partizione					INT				= NULL, --PER LA GESTIONE DI STAMPE NON LEGATE AD EVENTI
	@TemplateName					VARCHAR(MAX),
	@Codice_DDT						VARCHAR(11)		= NULL,
	@Codice_Udc						VARCHAR(MAX)	= NULL,
	@CODICE_ARTICOLO				VARCHAR(13)		= NULL,
	@Descrizione_Articolo			VARCHAR(120)	= NULL,
	@CODICE_ORDINE_ACQUISTO			VARCHAR(10)		= NULL,
	@CODICE_PRODUZIONE_ERP			VARCHAR(20)		= NULL,
	@COMM_PROD						VARCHAR(15)		= NULL,
	@COMM_SALE						VARCHAR(15)		= NULL,
	@DES_PREL_CONF					VARCHAR(512)	= NULL,
	@DETT_ETI						VARCHAR(275)	= NULL,
	@DOC_NUMBER						VARCHAR(40)		= NULL,
	@FL_LABEL						VARCHAR(1)		= NULL,
	@LINEA_PRODUZIONE_DESTINAZIONE	VARCHAR(80)		= NULL,
	@ORDER_ID						VARCHAR(40)		= NULL,
	@PFIN							VARCHAR(30)		= NULL,
	@PROD_LINE						VARCHAR(80)		= NULL,
	@PROD_ORDER						VARCHAR(20)		= NULL,
	@QUANTITA_ETICHETTA				NUMERIC(38,2)	= NULL,
	@UDM							VARCHAR(3)		= NULL,
	@DESCRIZIONE					VARCHAR(50)		= NULL,
	@CONTROL_LOT					VARCHAR(50)		= NULL,

	--PER GESTIONE KANBAN
	@BEHMG							NUMERIC(38,2)	= NULL,
	@PKBHT							VARCHAR(18)		= NULL,
	@ABLAD							VARCHAR(10)		= NULL,
	@ODA							VARCHAR(200)	= NULL,
	@SUPPLIER_CODE					VARCHAR(50)		= NULL,

	@N_STAMPE						INT				= NULL,
	@Id_Stampante					INT				= NULL,
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
		DECLARE @Id_Stampante_Finale	INT = @Id_Stampante
		DECLARE @AREA_TERRA				BIT

		IF EXISTS (SELECT TOP 1 1 FROM Partizioni P JOIN Eventi E ON E.Id_Partizione = P.ID_PARTIZIONE WHERE P.ID_TIPO_PARTIZIONE = 'AT' AND Id_Evento = @Id_Evento)
			SET @AREA_TERRA = 1

		IF @Id_Evento IS NULL OR ISNULL(@AREA_TERRA,0) = 1
		BEGIN
			IF @TemplateName IN ('pickingTestata','kittingTestata')
				SELECT	@Id_Stampante_Finale = PA.Id_Printer
				FROM	Custom.TestataListePrelievo	TPL
				JOIN	Printer.Printer_Association	PA
				ON		PA.Id_Partizione = TPL.Id_Partizione_Uscita
				WHERE	ORDER_ID = @ORDER_ID

			IF @TemplateName IN ('barcodeUdc','etichettaDdtAdige','barcodeUdc_1') OR ISNULL(@AREA_TERRA,0)=1
				SELECT	@Id_Stampante_Finale = Id_Printer
				FROM	PRINTER.Printer_Association
				WHERE	Id_Partizione = 3101
		END
		
		IF @Id_Stampante_Finale IS NULL
		BEGIN
			IF @Id_Partizione IS NULL
				SELECT	@Id_Partizione = Id_Partizione
				FROM	EVENTI
				WHERE	ID_EVENTO = @Id_Evento

			SELECT	@Id_Stampante_Finale = Id_Printer
			FROM	Printer.Printer_Association
			WHERE	Id_Partizione = @Id_Partizione

			IF @Id_Stampante_Finale IS NULL
			BEGIN
				IF @TemplateName IN ('pickingTestata','kittingTestata')
					SELECT	@Id_Stampante_Finale = PA.Id_Printer
					FROM	Custom.TestataListePrelievo	TPL
					JOIN	Printer.Printer_Association	PA
					ON		PA.Id_Partizione = TPL.Id_Partizione_Uscita
					WHERE	ORDER_ID = @ORDER_ID

				IF @TemplateName IN ('barcodeUdc','etichettaDdtAdige','barcodeUdc_1','barcodeArticolo') OR ISNULL(@AREA_TERRA,0)=1
					SELECT	@Id_Stampante_Finale = Id_Printer
					FROM	PRINTER.Printer_Association
					WHERE	Id_Partizione = 3101
				
				IF @Id_Stampante_Finale IS NULL
				BEGIN
					SET @Id_Stampante_Finale = 7
				
					DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('BAIA NON TROVATA PER L''EVENTO ', @ID_EVENTO)

					IF EXISTS (SELECT TOP 1 1 FROM Eventi WHERE Id_Evento = @Id_Evento AND Id_Partizione IS NOT NULL)
						SET @MSG_LOG = CONCAT(@MSG_LOG, ' L''EVENTO PERO'' HA UNA BAIA COLLEGATA')

					EXEC sp_Insert_Log
								@Id_Processo		= @Id_Processo,
								@Origine_Log		= @Origine_Log,
								@Proprieta_Log		= @Nome_StoredProcedure,
								@Id_Utente			= @Id_Utente,
								@Id_Tipo_Log		= 4,
								@Id_Tipo_Allerta	= 0,
								@Messaggio			= @MSG_LOG,
								@Errore				= @Errore OUTPUT;
				END
			END
		END

		IF @Id_Stampante_Finale IS NULL
			THROW 50009, 'Nessuna stampante associata alla baia dell''evento. ', 1

		IF @TemplateName = 'pickingArticoloMan'
		BEGIN
			IF @FL_LABEL = 'V'
				SET @TemplateName = 'pickingArticoloMan_F'
			ELSE
			BEGIN
				SET @TemplateName = 'pickingArticoloMan_NoF'
				SET @PROD_ORDER = NULL
			END
		END

		DECLARE @SAP_DOC_NUMBER VARCHAR(MAX)

		IF ISNULL(@DES_PREL_CONF,'') = ''
			AND @TemplateName = 'pickingArticolo'
		BEGIN
			SELECT	@DES_PREL_CONF = tlp.DES_PREL_CONF,
					@SAP_DOC_NUMBER = RLP.DOC_NUMBER
			FROM	AwmConfig.vUdcRighePrelievo vUP
			JOIN	Custom.TestataListePrelievo tlp
			ON		tlp.ID = vUP.Id_Testata_Lista
			JOIN	Custom.RigheListePrelievo	RLP
			ON		RLP.ID = vUP.Id_Riga_Lista
			WHERE	Id_Evento = @Id_Evento
		END

		DECLARE @JSONString VARCHAR(MAX)
		SET @CODICE_UDC = REPLACE(@CODICE_UDC,'<Codice_Udc>','')
		SET @CODICE_UDC = REPLACE(@CODICE_UDC,'</Codice_Udc>','')
		SET @Codice_Udc = REPLACE(@CODICE_UDC,'<Item>','')
		SET @CODICE_UDC = REPLACE(@CODICE_UDC,'</Item>','')
		
		IF @N_STAMPE IS NULL
			SET @N_STAMPE = CASE WHEN @CODICE_UDC IS NULL THEN 1 ELSE LEN(@CODICE_UDC)/10 END
		
		DECLARE @POS_CUDC INT = 1

		WHILE @N_STAMPE > 0
		BEGIN
			SET @JSONString = '{ '
			IF @Codice_DDT IS NOT NULL
				SET @JSONString = @JSONString + CONCAT('"Codice_DDT" : "',@Codice_DDT,'"')
		
			IF @Codice_Udc IS NOT NULL
			BEGIN
				IF @JSONString <> '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				
				SET @Codice_Udc = TRIM(REPLACE(REPLACE(REPLACE(@Codice_Udc, char(9), ''),CHAR(10), ''), CHAR(13),''))

				IF @TemplateName = 'barcodeUdc'
				BEGIN
					SET @JSONString = @JSONString + CONCAT('"Barcode" : "',SUBSTRING(@Codice_Udc,@POS_CUDC,10),'"')
					SET @JSONString = @JSONString + CONCAT(', "Codice_Udc" : "',SUBSTRING(@Codice_Udc,@POS_CUDC,10),'"')
				END
				ELSE
					SET @JSONString = @JSONString + CONCAT('"Codice_Udc" : "',SUBSTRING(@Codice_Udc,@POS_CUDC,10),'"')
				
				IF LEN(@Codice_Udc) > 10
					SET @POS_CUDC += 10
			END

			IF @CODICE_ARTICOLO	IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @CODICE_ARTICOLO = TRIM(REPLACE(REPLACE(REPLACE(@CODICE_ARTICOLO, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"CODICE_ARTICOLO" : "',@CODICE_ARTICOLO,'"')
			END

			IF @Descrizione_Articolo IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @Descrizione_Articolo = TRIM(REPLACE(REPLACE(REPLACE(REPLACE(@Descrizione_Articolo, char(9), ''),CHAR(10), ''), CHAR(13),''),'"',''))
				
				SET @JSONString = @JSONString + CONCAT('"DESCRIZIONE_ARTIC" : "',@Descrizione_Articolo,'"')

				IF @TemplateName IN ('pickingArticoloMan_NoF','pickingArticoloMan_F')
					SET @JSONString = @JSONString + CONCAT(', "DESCRIZIONE_ARTICOLO" : "',@Descrizione_Articolo,'"')
				
				IF @TemplateName IN ('etichettaSpecializzazioneAdd','pickingArticoloKanban','pickingArticoloKanban_Man')
					SET @JSONString = @JSONString + CONCAT(', "_________________DESCRIZIONE_ARTICOLO" : "',@Descrizione_Articolo,'"')
			END

			IF @CODICE_ORDINE_ACQUISTO IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @CODICE_ORDINE_ACQUISTO = TRIM(REPLACE(REPLACE(REPLACE(@CODICE_ORDINE_ACQUISTO, char(9), ''),CHAR(10), ''), CHAR(13),''))
				
				SET @JSONString = @JSONString + CONCAT('"CODICE_ORDINE_ACQUISTO" : "',@CODICE_ORDINE_ACQUISTO,'"')
			END

			IF @CODICE_PRODUZIONE_ERP IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @CODICE_PRODUZIONE_ERP = TRIM(REPLACE(REPLACE(REPLACE(@CODICE_PRODUZIONE_ERP, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"CODICE_PRODUZIONE_ERP" : "',@CODICE_PRODUZIONE_ERP,'"')
			END

			IF @COMM_PROD IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @COMM_PROD = TRIM(REPLACE(REPLACE(REPLACE(@COMM_PROD, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"COMM_PROD" : "',@COMM_PROD,'"')
			END

			IF @COMM_SALE IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				
				SET @COMM_SALE = TRIM(REPLACE(REPLACE(REPLACE(@COMM_SALE, char(9), ''),CHAR(10), ''), CHAR(13),''))
				IF @TemplateName = 'pickingTestata'
					SET @JSONString = @JSONString + CONCAT('"_______________COMM_SALE" : "',@COMM_SALE,'"')
				ELSE
					SET @JSONString = @JSONString + CONCAT('"COMM_SALE" : "',@COMM_SALE,'"')
			END

			IF @DES_PREL_CONF IS NOT NULL
			BEGIN
				SET @DES_PREL_CONF = REPLACE(@DES_PREL_CONF,'"','')
				SET @DES_PREL_CONF = TRIM(REPLACE(REPLACE(REPLACE(@DES_PREL_CONF, char(9), ''),CHAR(10), ''), CHAR(13),''))

				DECLARE @LEN_SUBSTRING INT = LEN(@DES_PREL_CONF)
				IF @LEN_SUBSTRING > 25
					SET @LEN_SUBSTRING = 25

				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
					SET @JSONString = @JSONString + CONCAT('"______DES_PREL_CONF__________" : "',SUBSTRING(@DES_PREL_CONF,1,@LEN_SUBSTRING),'"')
			END

			IF @DETT_ETI IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @DETT_ETI = TRIM(REPLACE(REPLACE(REPLACE(@DETT_ETI, char(9), ''),CHAR(10), ''), CHAR(13),''))

				IF LEN(@DETT_ETI)>20 
					SET @DETT_ETI = CONCAT(SUBSTRING(@DETT_ETI,1,17),'..')

				SET @JSONString = @JSONString + CONCAT('"DETTAGLIO_ETICHETTA" : "',@DETT_ETI,'"')
			END

			IF @DOC_NUMBER IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @DOC_NUMBER = TRIM(REPLACE(REPLACE(REPLACE(@DOC_NUMBER, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"DOC_NUMBER" : "',@DOC_NUMBER,'"')
			END

			IF @FL_LABEL IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @FL_LABEL = TRIM(REPLACE(REPLACE(REPLACE(@FL_LABEL, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"FL_LABEL" : "',@FL_LABEL,'"')
			END

			IF @LINEA_PRODUZIONE_DESTINAZIONE IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @LINEA_PRODUZIONE_DESTINAZIONE = TRIM(REPLACE(REPLACE(REPLACE(@LINEA_PRODUZIONE_DESTINAZIONE, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"LINEA_PRODUZIONE_DESTINAZIONE" : "',@LINEA_PRODUZIONE_DESTINAZIONE,'"')
			END

			IF @ORDER_ID IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				
				SET @ORDER_ID = TRIM(REPLACE(REPLACE(REPLACE(@ORDER_ID, char(9), ''),CHAR(10), ''), CHAR(13),''))
				IF @TemplateName = 'pickingTestata'
					SET @JSONString = @JSONString + CONCAT('"____________ORDER_ID" : "',@ORDER_ID,'"')
				ELSE
					SET @JSONString = @JSONString + CONCAT('"ORDER_ID" : "',@ORDER_ID,'"')
				
			END

			IF @PFIN IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @PFIN = TRIM(REPLACE(REPLACE(REPLACE(@PFIN, char(9), ''),CHAR(10), ''), CHAR(13),''))
				
				IF @TemplateName IN ('pickingArticoloMan_NoF')
					SET @JSONString = @JSONString + CONCAT('"_____PFIN" : "',@PFIN,'"')
				ELSE
					SET @JSONString = @JSONString + CONCAT('"PFIN" : "',@PFIN,'"')
			END

			IF @PROD_LINE IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @PROD_LINE = TRIM(REPLACE(REPLACE(REPLACE(@PROD_LINE, char(9), ''),CHAR(10), ''), CHAR(13),''))

				SET @JSONString = @JSONString + CONCAT('"PROD_LINE" : "',@PROD_LINE,'"')
			END

			IF @PROD_ORDER IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @PROD_ORDER = TRIM(REPLACE(REPLACE(REPLACE(@PROD_ORDER, char(9), ''),CHAR(10), ''), CHAR(13),''))

				SET @JSONString = @JSONString + CONCAT('"PROD_ORDER" : "',@PROD_ORDER,'"')
			END

			IF @QUANTITA_ETICHETTA IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @JSONString = @JSONString + CONCAT('"Quantita_etichetta" : "',@QUANTITA_ETICHETTA,'"')
			END

			IF @UDM IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @UDM = TRIM(REPLACE(REPLACE(REPLACE(@UDM, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"UDM" : "',@UDM,'"')
			END

			IF @DESCRIZIONE IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @DESCRIZIONE = TRIM(REPLACE(REPLACE(REPLACE(@DESCRIZIONE, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"DESCRIZIONE" : "',@DESCRIZIONE,'"')
			END

			IF @SAP_DOC_NUMBER IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @SAP_DOC_NUMBER = TRIM(REPLACE(REPLACE(REPLACE(@SAP_DOC_NUMBER, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"SAP_DOC_NUMBER" : "',@SAP_DOC_NUMBER,'"')
			END

			IF @CONTROL_LOT IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @CONTROL_LOT = TRIM(REPLACE(REPLACE(REPLACE(@CONTROL_LOT, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"CONTROL_LOT" : "',@CONTROL_LOT,'"')
			END

			--AGGIUNTA PER GESTIONE ETICHETTE KANBAN
			IF @BEHMG IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @JSONString = @JSONString + CONCAT('"BEHMG" : "',@BEHMG ,'"')
			END
			
			IF @PKBHT IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @PKBHT = TRIM(REPLACE(REPLACE(REPLACE(@PKBHT, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"PKBHT" : "',@PKBHT,'"')
			END

			IF @ABLAD IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @ABLAD = TRIM(REPLACE(REPLACE(REPLACE(@ABLAD, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"ABLAD" : "',@ABLAD,'"')
			END

			IF @ODA IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @ODA = TRIM(REPLACE(REPLACE(REPLACE(@ODA, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"ODA" : "',@ODA,'"')
			END

			IF @SUPPLIER_CODE IS NOT NULL
			BEGIN
				IF @JSONString <>  '{ ' SET @JSONString = CONCAT(@JSONString, ', ')
				SET @SUPPLIER_CODE = TRIM(REPLACE(REPLACE(REPLACE(@SUPPLIER_CODE, char(9), ''),CHAR(10), ''), CHAR(13),''))
				SET @JSONString = @JSONString + CONCAT('"SUPPLIER_CODE" : "',@SUPPLIER_CODE,'"')
			END

			--FINE GESTIONE KANBAN
			
			SET @JSONString = CONCAT(@JSONString,'}')

			-- Dichiarazioni Variabili;
			INSERT INTO Printer.PrinterRequest
				(Id_Stampante, TemplateName,JsonString,Id_Tipo_Stato_Messaggio,Data_Esecuzione)
			VALUES
				(@Id_Stampante_Finale, @TemplateName, @JSONString, 1, getdate())

			SET @N_STAMPE -= 1
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
