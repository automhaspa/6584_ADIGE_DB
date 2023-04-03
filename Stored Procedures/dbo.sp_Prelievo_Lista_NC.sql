SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_Prelievo_Lista_NC]
	--Id della Testata
	@Id_Articolo			INT,
	@Id_Partizione			INT,
	@QTA_Richiesta			NUMERIC(18,4),
	@Id_Testata				INT,
	@Id_Riga				INT,
	@Kit_ID					INT,

	@QTA_Selezionata		NUMERIC(18,4)	= 0			OUTPUT,

	@WBS_Riferimento_C		VARCHAR(40)		= NULL,
	@MOTIVO_NC				VARCHAR(MAX)	= NULL,
	-- Parametri Standard;
	@Id_Processo			VARCHAR(30),
	@Origine_Log			VARCHAR(25),
	@Id_Utente				VARCHAR(32),
	@Errore					VARCHAR(500) OUTPUT
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
		DECLARE @Id_UdcDettaglio_C				INT			= NULL
		DECLARE @Id_Udc_C						INT			= NULL
		DECLARE @Qta_Nc_C						INT			= 0
		DECLARE @Id_Tipo_Udc_C					VARCHAR(2)	= ''

		DECLARE @Flag_Svuota_Compl				INT			= 0
		DECLARE @Id_Partizione_Dest_Missione	INT			= 0
		DECLARE @QTA_DaPrelevare				INT			= 0
		
		--Scorro le Udc contenenti quel codice articolo in NC
		DECLARE CursoreUdc CURSOR LOCAL FORWARD_ONLY FOR
			SELECT	UD.Id_UdcDettaglio,
					UD.Id_Udc,
					NC.Quantita,
					UT.Id_Tipo_Udc
			FROM	Custom.NonConformita			NC
			JOIN	Udc_Dettaglio					UD
			ON		UD.Id_UdcDettaglio = NC.Id_UdcDettaglio
				AND UD.Id_Articolo = @Id_Articolo
				AND UD.Id_Udc <> 702
				AND ISNULL(UD.WBS_Riferimento,'') = ISNULL(@WBS_Riferimento_C,'')
			JOIN	Udc_Posizione				UP
			ON		UP.Id_Udc = UD.Id_Udc
			JOIN	Partizioni					P
			ON		P.Id_Partizione = UP.Id_Partizione
				--Esludo le udc in area a terra, in uscita o in area packing list perchè non sono utilizzabili
				AND P.ID_TIPO_PARTIZIONE NOT IN ('AT', 'KT', 'AP', 'US', 'OO')
			JOIN	Udc_Testata					UT
			ON		UT.Id_Udc = UD.Id_Udc
				AND ISNULL(UT.Blocco_Udc,0) = 0
			--Quantità impegnate in altre liste gestite dalla Missioni_Picking_Dettaglio
			LEFT
			JOIN	Missioni_Picking_Dettaglio		MPD
			ON		MPD.ID_UDC = UD.ID_UDC
				AND MPD.ID_UDCDETTAGLIO = UD.ID_UDCDETTAGLIO
				AND Id_Stato_Missione IN (1,2)
			LEFT
			JOIN	Custom.OrdineKittingUdc		OKU
			ON		OKU.Id_Udc = UT.Id_Udc
			WHERE	1 = 1
				AND OKU.Id_Testata_Lista IS NULL
				AND MPD.Id_Udc IS NULL
				AND ISNULL(NC.MotivoNonConformita,'') =	CASE
															WHEN ISNULL(@MOTIVO_NC,'') = '' THEN ISNULL(NC.MotivoNonConformita,'')
															ELSE @MOTIVO_NC
														END
			GROUP
				BY	UD.Id_UdcDettaglio,
					UD.Id_Udc,
					NC.Quantita,
					UT.Id_Tipo_Udc,
					UD.Data_Creazione,
					UT.Data_Inserimento
			ORDER
				BY	NC.Quantita				ASC, --VADO A SVUOTAMENTO
					UD.Data_Creazione		DESC,
					UT.Data_Inserimento		DESC

		OPEN CursoreUdc 
		FETCH NEXT FROM CursoreUdc  INTO
				@Id_UdcDettaglio_C,
				@Id_Udc_C,
				@Qta_Nc_C,
				@Id_Tipo_Udc_C

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Flag_Svuota_Compl				= 0
			SET @QTA_DaPrelevare				= 0

			--se di tipo B va in 3B03
			SET @Id_Partizione_Dest_Missione	=	CASE
														WHEN @Id_Tipo_Udc_C IN ('1','2','3','I','M') THEN @Id_Partizione
														WHEN @Id_Tipo_Udc_C IN ('4','5','6')	THEN 3203
													END

			--Se per quell'Udc ho più Articoli della dettaglio di quanti me ne servono non la svuoto completamente
			IF (@QTA_Selezionata + @Qta_Nc_C) > @QTA_Richiesta
			BEGIN
				SET @Flag_Svuota_Compl = 0
				SET @QTA_DaPrelevare = @QTA_Richiesta - @QTA_Selezionata
							
				--Inserisco nelle missioni dettaglio
				INSERT INTO Missioni_Picking_Dettaglio
					(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Id_Stato_Missione,Id_Partizione_Destinazione, Kit_Id)
				VALUES
					(@Id_Udc_C,@Id_UdcDettaglio_C,@Id_Testata, @Id_Riga, @Id_Articolo, @QTA_DaPrelevare, @Flag_Svuota_Compl,
							(CASE WHEN (@Id_Tipo_Udc_C = 'I') THEN 2 ELSE 1 END), @Id_Partizione_Dest_Missione, @Kit_Id)

				SET @QTA_Selezionata = @QTA_Richiesta
			END
			--Se l'udc non basta per soddisfare la quantità richiesta
			ELSE
			BEGIN
				SET @Flag_Svuota_Compl = 1
				SET @QTA_Selezionata += @Qta_Nc_C

				INSERT INTO Missioni_Picking_Dettaglio
					(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Id_Stato_Missione, Id_Partizione_Destinazione, Kit_Id)
				VALUES
					(@Id_Udc_C,@Id_UdcDettaglio_C,@Id_Testata, @Id_Riga, @Id_Articolo, @Qta_Nc_C, @Flag_Svuota_Compl, (CASE WHEN @Id_Tipo_Udc_C IN ('I','M') THEN 2 ELSE 1 END),
						@Id_Partizione_Dest_Missione, @Kit_ID)
			END

			--Se ho distribuito completamente
			IF @QTA_Selezionata = @QTA_Richiesta
				BREAK;

			FETCH NEXT FROM CursoreUdc  INTO
				@Id_UdcDettaglio_C,
				@Id_Udc_C,
				@Qta_Nc_C,
				@Id_Tipo_Udc_C
		END

		CLOSE CursoreUdc
		DEALLOCATE CursoreUdc
		
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
