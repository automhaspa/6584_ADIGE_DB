SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROC [dbo].[sp_Invia_Ordine_Entrata_Modula_NoSap]
	@Id_UdcDettaglio	INT,
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

	-- Se il numero di transazioni � 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION;

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @Id_Testata			INT = 1

		SELECT	@Id_Testata = MAX(CAST(SUBSTRING(LOAD_ORDER_ID,LEN(LOAD_ORDER_ID) - CHARINDEX(LOAD_ORDER_ID,'AWM'),LEN(LOAD_ORDER_ID)) AS INT))
		FROM	MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_ORDERS
		WHERE	LOAD_ORDER_ID LIKE 'AWM%'

		DECLARE @Id_Testata_String	VARCHAR(MAX) = CONCAT('AWM',@Id_Testata)

		DECLARE @Id_Missione				INT = 0;
		DECLARE @Id_Partizione_Destinazione INT = 9101 --CABLATO ID_UDC MODULA  = 702 --Id_partizione_Destinazione 9A01
		
		--CONSUNTIVO L3
		IF EXISTS	(
						SELECT	1
						FROM	MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_ORDERS
						WHERE	LOAD_ORDER_ID = @Id_Testata_String
					)
		BEGIN
			DECLARE @MSG VARCHAR(MAX) = CONCAT('ID_TESTATA: ', @Id_Testata_String,' CONTROLLARE TABELLA DI SCAMBIO MODULA HOST_INCOMING_ORDERS RECORD DUPLICATO DI TESTATA.')
			;THROW 50001, @MSG,1
		END

		SET XACT_ABORT ON
		--(MIS_IdMissione)  LA quantita che movimento è pari alla quantità pezzi presente sull'Udc
		
		INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_LINES
		SELECT	@Id_Testata_String, 
				A.CODICE,
				CONCAT('n_' , 1),
				ud.Quantita_Pezzi,
				'NOS',
				' ',
				' ',
				' ',
				NULL
		FROM	Udc_Dettaglio		UD
		JOIN	Articoli			A
		ON		A.Id_Articolo = UD.Id_Articolo
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

		INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_INCOMING_ORDERS
		SELECT	@Id_Testata_String,
				'NOS',
				' '		SUPPLIER_CODE,
				' '		DES_SUPPLIER_CODE,
				' '		SUPPLIER_DDT_CODE,
				' '		DT_RECEIVE_BLM,
				NULL,
				' ',
				' '
		FROM	Udc_Dettaglio
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio

		SET XACT_ABORT OFF
		
		--Inserisco la Missione AreaATerra---->Magazzino Modula per l'udc
		EXEC @Return = dbo.sp_Insert_CreaMissioni
				@Id_Udc						= 702,
				@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
				@Id_Tipo_Missione			= 'MTM',
				@Id_Missione				= @ID_MISSIONE	OUTPUT,
				@Id_Processo				= @Id_Processo,
				@Origine_Log				= @Origine_Log,
				@Id_Utente					= @Id_Utente,
				@Errore						= @Errore		OUTPUT

		IF (@Id_Missione = 0)
			THROW 50010, ' IMPOSSIBILE CREARE MISSIONE DI SPOSTAMENTO TRA MAGAZZINI', 1;

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
