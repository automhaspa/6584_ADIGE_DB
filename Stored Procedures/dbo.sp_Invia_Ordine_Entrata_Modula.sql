SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROC [dbo].[sp_Invia_Ordine_Entrata_Modula]
	@Id_Udc				INT,
	@Id_Testata			INT,
	--LOAD LINE ID
	@NUMERO_RIGA		INT,
	@Invia_Dati_A_Sap	BIT = 1,
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(32),
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

	-- Se il numero di transazioni � 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		-- Dichiarazioni Variabili;
		IF (@Id_Testata = 0 OR @NUMERO_RIGA = 0)
			THROW 50004, 'ID TESTATA DDT O LOAD LINE ID NON DEFINITI SULL ''UDC IN QUESTIONE',1

		DECLARE @Id_Missione				INT = 0;
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @Load_Order_Id				VARCHAR(10)
		DECLARE @Load_Order_type			VARCHAR(3)

		--CABLATO ID_UDC MODULA  = 702 --Id_partizione_Destinazione 9A01
		SELECT	@Id_Partizione_Destinazione = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = 702

		--CONSUNTIVO L3
		IF EXISTS	(
						SELECT	1
						FROM	MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_ORDERS
						WHERE	LOAD_ORDER_ID IN	(
														SELECT	LOAD_ORDER_ID
														FROM	Custom.TestataOrdiniEntrata
														WHERE	ID = @Id_Testata
													)
					)
		BEGIN
			DECLARE @MSG VARCHAR(MAX) = CONCAT('ID_TESTATA: ', @Id_Testata,' CONTROLLARE TABELLA DI SCAMBIO MODULA HOST_INCOMING_ORDERS RECORD DUPLICATO DI TESTATA.')
			;THROW 50001, @MSG,1
		END

		SET XACT_ABORT ON
		--(MIS_IdMissione)  LA quantita che movimento è pari alla quantità pezzi presente sull'Udc
		
		INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_LINES
		SELECT	toe.LOAD_ORDER_ID, roe.ITEM_CODE,
				--CONCAT(ISNULL(roe.PURCHASE_ORDER_ID, 'n'), '_' , roe.LOAD_LINE_ID),
				CASE
					WHEN ISNULL(roe.PURCHASE_ORDER_ID, '') = '' THEN CONCAT('n_' , roe.LOAD_LINE_ID)
					ELSE CONCAT(roe.PURCHASE_ORDER_ID, '_' , roe.LOAD_LINE_ID)
				END,
				ud.Quantita_Pezzi,
				CASE WHEN @Invia_Dati_A_Sap = 1 THEN TOE.LOAD_ORDER_TYPE ELSE NULL END,
				CAST(roe.FL_INDEX_ALIGN as varchar(40)), roe.MANUFACTURER_ITEM, roe.MANUFACTURER_NAME, NULL
		FROM	Udc_Dettaglio				UD
		JOIN	Custom.TestataOrdiniEntrata toe
		ON		ud.Id_Ddt_Reale = toe.ID
		JOIN	Custom.RigheOrdiniEntrata	roe
		ON		ud.Id_Riga_Ddt = roe.LOAD_LINE_ID
			AND ud.Id_Ddt_Reale = roe.Id_Testata
		WHERE	Id_Ddt_Reale = @Id_Testata
			AND Id_Riga_Ddt = @NUMERO_RIGA
			AND Id_Udc = @Id_Udc

		INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_ORDERS
		SELECT	toe.LOAD_ORDER_ID,
				CASE WHEN @Invia_Dati_A_Sap = 1 THEN TOE.LOAD_ORDER_TYPE ELSE NULL END,
				ISNULL(toe.SUPPLIER_CODE, ' '),
				ISNULL(toe.DES_SUPPLIER_CODE, ' '),
				ISNULL(toe.SUPPLIER_DDT_CODE, ' '),
				ISNULL(CAST(toe.DT_RECEIVE_BLM AS date), ' '),
				NULL,
				' ',
				' '
		FROM	Udc_Dettaglio				UD
		JOIN	Custom.TestataOrdiniEntrata toe
		ON		ud.Id_Ddt_Reale = toe.ID
		WHERE	Id_Ddt_Reale = @Id_Testata
			AND Id_Riga_Ddt = @NUMERO_RIGA
			AND Id_Udc = @Id_Udc
		SET XACT_ABORT OFF
		
		IF NOT EXISTS (SELECT TOP 1 1 FROM Missioni WHERE ID_UDC = @Id_Udc)
		BEGIN
			--Inserisco la Missione AreaATerra---->Magazzino Modula per l'udc
			EXEC @Return = dbo.sp_Insert_CreaMissioni
					@Id_Udc						= @Id_Udc,
					@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
					@Id_Tipo_Missione			= 'MTM',
					@Id_Missione				= @ID_MISSIONE	OUTPUT,
					@Id_Processo				= @Id_Processo,
					@Origine_Log				= @Origine_Log,
					@Id_Utente					= @Id_Utente,
					@Errore						= @Errore		OUTPUT

			IF (@Id_Missione = 0)
				THROW 50010, ' IMPOSSIBILE CREARE MISSIONE DI SPOSTAMENTO TRA MAGAZZINI', 1;
		END

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION;
		-- Return 0 se tutto � andato a buon fine;
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
			
				-- Return 1 se la procedura � andata in errore;
				RETURN 1;
			END
		ELSE
			THROW;
	END CATCH;
END;


GO
