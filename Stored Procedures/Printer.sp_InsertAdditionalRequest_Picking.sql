SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [Printer].[sp_InsertAdditionalRequest_Picking]
	@Id_Evento			INT				= NULL,
	@Id_Partizione		INT				= NULL,
	@Id_Articolo		INT,
	@Quantita_Articolo	NUMERIC(18,4),
	@Id_Riga_Lista		INT,
	@Id_Testata_Lista	INT,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(16),
	@Errore				VARCHAR(500) OUTPUT
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
		DECLARE @CODICE_ARTICOLO				VARCHAR(50)
		DECLARE @DESCRIZIONE_ARTICOLO			VARCHAR(50)
		DECLARE @CODICE_PRODUZIONE_ERP			VARCHAR(20)
		DECLARE @COMM_PROD						VARCHAR(15)
		DECLARE @COMM_SALE						VARCHAR(15)
		DECLARE @FL_LABEL						VARCHAR(1)
		DECLARE @LINEA_PRODUZIONE_DESTINAZIONE	VARCHAR(80)
		DECLARE @ORDER_ID						VARCHAR(40)
		DECLARE @PFIN							VARCHAR(30)
		DECLARE @QUANTITA_ETICHETTA				NUMERIC(38,2)
		DECLARE @UDM							VARCHAR(3)

		DECLARE @BEHMG							NUMERIC(38,4)
		DECLARE @PKBHT 							VARCHAR(18)
		DECLARE @ABLAD							VARCHAR(10)
		DECLARE @ORDER_TYPE						VARCHAR(3)
		DECLARE @TemplateName					VARCHAR(200)	= 'pickingArticolo'

		SELECT	@CODICE_ARTICOLO					= A.Codice,
				@DESCRIZIONE_ARTICOLO				= A.Descrizione,
				@CODICE_PRODUZIONE_ERP				= rlp.PROD_ORDER,
				@COMM_PROD							= ISNULL(rlp.COMM_PROD,tlp.COMM_PROD),
				@COMM_SALE							= ISNULL(RLP.COMM_SALE,TLP.COMM_SALE),
				@FL_LABEL							= tlp.FL_LABEL,
				@LINEA_PRODUZIONE_DESTINAZIONE		= RLP.PROD_LINE,
				@ORDER_ID							= TLP.ORDER_ID,
				@PFIN								= TLP.PFIN,
				@QUANTITA_ETICHETTA					= @Quantita_Articolo,
				@UDM								= A.Unita_Misura,
				@ORDER_TYPE							= TLP.ORDER_TYPE,
				@BEHMG								= RLP.BEHMG,
				@PKBHT								= RLP.PKBHT,
				@ABLAD								= RLP.ABLAD
		FROM	Custom.RigheListePrelievo		RLP
		JOIN	Custom.TestataListePrelievo		TLP
		ON		RLP.Id_Testata = TLP.ID
		JOIN	dbo.Articoli					A
		ON		RLP.ITEM_CODE = A.Codice
		WHERE	TLP.ID = @Id_Testata_Lista
			AND RLP.ID = @Id_Riga_Lista

		IF @ORDER_TYPE = 'PXP'	--PRELIEVO PER KANBAN
		BEGIN
			SET @TemplateName = 'pickingArticoloKanban'
			SET @CODICE_ARTICOLO = REPLACE(@CODICE_ARTICOLO,'#','-')
		END
		
		--stampo etichetta qta aggiuntiva
		EXEC Printer.sp_AddPrinterRequest
				@Id_Evento							= @Id_Evento,
				@Id_Partizione						= @Id_Partizione,
				@TemplateName						= @TemplateName,
				@CODICE_ARTICOLO					= @CODICE_ARTICOLO,
				@DESCRIZIONE_ARTICOLO				= @DESCRIZIONE_ARTICOLO,
				@CODICE_PRODUZIONE_ERP				= @CODICE_PRODUZIONE_ERP,
				@COMM_PROD							= @COMM_PROD,
				@COMM_SALE							= @COMM_SALE,
				@FL_LABEL							= @FL_LABEL,
				@LINEA_PRODUZIONE_DESTINAZIONE		= @LINEA_PRODUZIONE_DESTINAZIONE,
				@ORDER_ID							= @ORDER_ID,
				@PFIN								= @PFIN,
				@QUANTITA_ETICHETTA					= @QUANTITA_ETICHETTA,
				@UDM								= @UDM,
				
				--AGGIUNTA GESTIONE KANBAN
				@BEHMG								= @BEHMG,
				@PKBHT								= @PKBHT,
				@ABLAD								= @ABLAD,

				@Id_Processo						= @Id_Processo,
				@Id_Utente							= @Id_Utente,
				@Origine_Log						= @Origine_Log,
				@Errore								= @Errore			OUTPUT
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
