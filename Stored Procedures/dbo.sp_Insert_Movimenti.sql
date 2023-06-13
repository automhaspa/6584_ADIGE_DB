SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Insert_Movimenti]
	@Id_Udc						INT,
	@Id_Articolo				INT,
	@Lotto						VARCHAR(20),
	@Qta						NUMERIC(18, 4),
	@Id_Tipo_Causale_Movimento	INT,
	@Codice_Lista				VARCHAR(30),
	@Codice_Riga				VARCHAR(7),
	@DtLotto					DATETIME = NULL,
	@DtScadenza					DATETIME = NULL,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(32),
	@Errore						VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

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
		DECLARE @Codice_Articolo	VARCHAR(50)
		DECLARE @Descrizione		VARCHAR(50)
		DECLARE @Id_Partizione		INT
		DECLARE @Codice_Udc			VARCHAR(50)
		DECLARE @Unita_Misura		VARCHAR(3)

		--Custom Adige
		DECLARE @IdTestataLP	INT = NULL,
				@IdRigaLP		INT = NULL,
				@IdTestataDDT	INT = NULL,
				@IdRigaDDT		INT = NULL,
				@CausaleL3Mov	VARCHAR(3) = NULL

		DECLARE @CODICE_ORDINE			VARCHAR(50),
				@CAUSALE				VARCHAR(4),
				@PROD_ORDER_LOTTO		VARCHAR(50),
				@DESTINAZIONE_RAGSOC	VARCHAR(50),
				@CONSEGNA_DDT			VARCHAR(50)
				
		SELECT	@Codice_Articolo = Codice,
				@Descrizione = Descrizione,
				@Unita_Misura = Unita_Misura
		FROM	Articoli WITH(NOLOCK)
		WHERE	Id_Articolo = @Id_Articolo

		--PICKING LISTA
		IF (@Id_Tipo_Causale_Movimento = 1)
		BEGIN
			;WITH DATI_PRELIEVO AS
			(
				SELECT	UD.Id_UdcDettaglio,
						TLP.ORDER_ID,
						TLP.ORDER_TYPE,
						RLP.PROD_ORDER,
						CASE WHEN TLP.ORDER_TYPE IN ('STS','PAT','PCL') THEN substring(TLP.DES_PREL_CONF,1,50) ELSE RLP.PROD_LINE END		PROD_LINE,
						ISNULL(RLP.DOC_NUMBER,'')						DOC_NUMBER
				FROM	Udc_Dettaglio				UD WITH(NOLOCK)
				JOIN	Custom.RigheListePrelievo	RLP
				ON		UD.Id_Riga_Lista_Prelievo = RLP.ID
					AND RLP.ITEM_CODE = @Codice_Articolo
				JOIN	Custom.TestataListePrelievo	TLP
				ON		UD.Id_Testata_Lista_Prelievo = TLP.ID
				WHERE	UD.Id_Udc = @Id_Udc
					AND UD.Id_Articolo = @Id_Articolo
			)
			SELECT	@IdTestataLP = Id_Testata_Lista_Prelievo,
					@IdRigaLP = Id_Riga_Lista_Prelievo,
					@CausaleL3Mov = Id_Causale_L3,
					
					/*
					per prelievi da lista:
					- Codice lista				ORDER_ID
					- Causale lista				ORDER_TYPE
					- Prod order della riga		PROD_ORDER	RIGA
					- Destinazione				SE ORDER_TYPE IN ('STS','PAT','PCL') DES_PREL_CONF TESTATA ALTRIMENTI PROD_LINE RIGA
					- Consegna					DOC_NUMBER	RIGA
					*/

					@CODICE_ORDINE			= DP.ORDER_ID,
					@CAUSALE				= DP.ORDER_TYPE,
					@PROD_ORDER_LOTTO		= DP.PROD_ORDER,
					@DESTINAZIONE_RAGSOC	= DP.PROD_LINE,
					@CONSEGNA_DDT			= DP.DOC_NUMBER
			FROM	Udc_Dettaglio				UD WITH(NOLOCK)
			LEFT
			JOIN	DATI_PRELIEVO				DP
			ON		DP.Id_UdcDettaglio = UD.Id_UdcDettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo

		END
		--PICKING MANUALE
		ELSE IF (@Id_Tipo_Causale_Movimento = 2)
			SELECT	@CausaleL3Mov = Id_Causale_L3,
					@IdTestataLP = Id_Testata_Lista_Prelievo,
					@IdRigaLP = Id_Riga_Lista_Prelievo
			FROM	Udc_Dettaglio WITH(NOLOCK)
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo

		--CARICO MANUALE
		ELSE IF (@Id_Tipo_Causale_Movimento = 3)
			SELECT	@CausaleL3Mov = Id_Causale_L3
			FROM	Udc_Dettaglio WITH(NOLOCK)
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo

		--CARICO DA LISTA
		ELSE IF (@Id_Tipo_Causale_Movimento = 7)
		BEGIN
			;WITH DATI_DDT AS
			(
				SELECT	UD.Id_UdcDettaglio,
						toe.ID,
						roe.LOAD_LINE_ID,
						TOE.LOAD_ORDER_TYPE,
						ROE.PURCHASE_ORDER_ID,
						TOE.DES_SUPPLIER_CODE,
						TOE.SUPPLIER_DDT_CODE,
						ROE.CONTROL_LOT
				FROM	Udc_Dettaglio					UD WITH(NOLOCK)
				JOIN	Custom.RigheOrdiniEntrata		ROE
				ON		ROE.LOAD_LINE_ID = UD.Id_Riga_Ddt
					AND ROE.ITEM_CODE = @CODICE_ARTICOLO
				JOIN	Custom.TestataOrdiniEntrata		TOE
				ON		ROE.Id_Testata = TOE.ID
					and TOE.ID = UD.Id_Ddt_Reale
				WHERE	Id_Udc = @Id_Udc
					AND Id_Articolo = @Id_Articolo
			)
			SELECT	@IdTestataDDT = Id_Ddt_Reale,
					@IdRigaDDT = Id_Riga_Ddt,
					@CausaleL3Mov = Id_Causale_L3,
					/*
					per il carico da ordine
					- Causale				LOAD_ORDER_TYPE
					- Ordine				LOAD_ORDER_ID
					- Ragione sociale		DES_SUPPLIER_CODE
					- Numero ddt			CODICE_ORDINE_ACQUISTO
					- Nr lotto
					*/
					@CAUSALE				= DD.LOAD_ORDER_TYPE,
					@CODICE_ORDINE			= DD.PURCHASE_ORDER_ID,
					@DESTINAZIONE_RAGSOC	= DD.DES_SUPPLIER_CODE,
					@CONSEGNA_DDT			= DD.SUPPLIER_DDT_CODE,
					@PROD_ORDER_LOTTO		= DD.CONTROL_LOT
			FROM	Udc_Dettaglio					UD WITH(NOLOCK)
			LEFT
			JOIN	DATI_DDT			DD
			ON		DD.Id_UdcDettaglio = UD.Id_UdcDettaglio
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo
		END
		--CANCELLAZIONE
		ELSE IF (@Id_Tipo_Causale_Movimento = 6)
			SELECT	@IdTestataLP = Id_Testata_Lista_Prelievo,
					@IdRigaLP = Id_Riga_Lista_Prelievo,
					@IdTestataDDT = Id_Ddt_Reale,
					@IdRigaDDT = Id_Riga_Ddt,
					@CausaleL3Mov = Id_Causale_L3
			FROM	Udc_Dettaglio WITH(NOLOCK)
			WHERE	Id_Udc = @Id_Udc
				AND Id_Articolo = @Id_Articolo


		SELECT	@Id_Partizione = Id_Partizione 
		FROM	Udc_Posizione WITH(NOLOCK)
		WHERE	Udc_Posizione.Id_Udc = @Id_Udc
		
		SELECT	@Codice_Udc = Codice_Udc
		FROM	Udc_Testata WITH(NOLOCK)
		WHERE	Udc_Testata.Id_Udc = @Id_Udc

		IF NOT (@Id_Partizione IS NULL AND @Id_Tipo_Causale_Movimento = 6)
			INSERT INTO Movimenti
				(Data_Movimento,Id_Udc,Id_Articolo,Codice_Articolo,Descrizione,Lotto,Unita_Misura,Quantita,Id_Utente,Id_Causale_Movimenti,Id_Partizione,Codice_Lista,Codice_Riga,Codice_Udc,
					Data_Lotto, Data_Scadenza, Id_Causale_L3, Id_Testata_Lista_Prelievo, Id_Riga_Lista_Prelievo, Id_Testata_Ddt_Reale, Id_Riga_Ddt_Reale, Annotazione
					--aggiunta dati
					,CODICE_ORDINE,CAUSALE,PROD_ORDER_LOTTO,DESTINAZIONE_DDT,CONSEGNA_RAGSOC)
			VALUES
				(GETDATE(), @Id_Udc, @Id_Articolo, @Codice_Articolo, @Descrizione,@Lotto,@Unita_Misura,@Qta,@Id_Utente,@Id_Tipo_Causale_Movimento,@Id_Partizione,@Codice_Lista,@Codice_Riga,@Codice_Udc,
					@DtLotto, @DtScadenza, @CausaleL3Mov, @IdTestataLP, @IdRigaLP, @IdTestataDDT, @IdRigaDDT, NULL
					,@CODICE_ORDINE,@CAUSALE,@PROD_ORDER_LOTTO,@DESTINAZIONE_RAGSOC,@CONSEGNA_DDT)

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
		END
		-- Return 0 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END

GO
