SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Avvia_Lista_Prelievo]
	--Id della Testata
	@ID				INT,
	@Id_Partizione	INT				= NULL,
	@FlagKit		BIT				= 0,
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
		declare @start datetime = getdate()

		-- Dichiarazioni Variabili;
		DECLARE @Id_Udc_Modula		INT		= 702
		DECLARE @Stato				INT		= 0
		DECLARE @Order_Id			VARCHAR(40)
		DECLARE @Order_Type			VARCHAR(3)
		DECLARE @Item_Code_C_Fin	VARCHAR(30)
		DECLARE @Dett_Eti			VARCHAR(30)
		DECLARE @Comm_Sale_Testata	VARCHAR(30)
		DECLARE @Des_Prel_Conf		VARCHAR(30)
		DECLARE @Prod_Line_Testata	VARCHAR(30)

		IF @ID IS NULL
			THROW 50008, 'ID lista non definito', 1;

		SELECT	@Stato				= Stato,
				@Order_Id			= ORDER_ID,
				@Order_Type			= ORDER_TYPE,
				@Item_Code_C_Fin	= ITEM_CODE_FIN,
				@Dett_Eti			= DETT_ETI,
				@Comm_Sale_Testata	= COMM_SALE,
				@Des_Prel_Conf		= DES_PREL_CONF,
				@Prod_Line_Testata	= PROD_LINE
		FROM	Custom.TestataListePrelievo
		WHERE	ID = @ID

		IF @Id_Partizione IS NULL
			THROW 50011, 'Partizione di destinazione lista non selezionata', 1
		IF @Stato = 2
			THROW 50009, 'Impossibile evadere una lista già in esecuzione', 1
		ELSE IF @Stato = 4
			THROW 50010, 'Impossibile evadere una lista già conclusa', 1

		ELSE IF @Stato IN (1,3) --SE MI ARRIVA DA UNO STATO PRELEVABILE PREDISPONGO LA LISTA DI PRELIEVO
		BEGIN
			-- SE E' IN STATO 3 (EVASA CON MANCANTI) DEVO VERIFICARE SE HO DELLE UDC GIA' RISERVATE/ESEGUITE PER QUESTA LISTA, SE NON NE HO ALLORA E' PRELEVABILE
			IF @Stato = 3
			BEGIN
				IF EXISTS(SELECT 1 FROM dbo.Missioni_Picking_Dettaglio WHERE Id_Testata_Lista = @ID)
					THROW 50010, 'Lista con mancanti già eseguita. Impossibile avviare una seconda volta.', 1
			END
			
			UPDATE	Custom.TestataListePrelievo
			SET		Id_Partizione_Uscita = @Id_Partizione
			WHERE	ID = @ID

			DECLARE @Id_Riga_C							INT
			DECLARE @Line_Id_C							INT
			DECLARE @Item_Code_C						VARCHAR(14)
			DECLARE @Prod_Order_C						VARCHAR(20)
			DECLARE @Quantity_C							NUMERIC(10,2)
			DECLARE @Comm_Prod_C						VARCHAR(30)
			DECLARE @Prod_Line_C						VARCHAR(80)
			DECLARE @Kit_Id_C							INT
			DECLARE @WBS_Riferimento_C					VARCHAR(24)
			DECLARE @Comm_Sale_Riga_C					VARCHAR(30)
			DECLARE @Magazzino_NC_C						BIT = 0
			DECLARE @Motivo_NC_C						VARCHAR(25)

			DECLARE @Quantita_Distribuita				NUMERIC(10,2)
			DECLARE @Id_Articolo						INT
			DECLARE @Quantita_Impegnata_Modula			NUMERIC(10,2)
			DECLARE @Quantita_Presente_Modula			NUMERIC(10,2)
			DECLARE @Disponibilita_Effettiva_Modula		NUMERIC(10,2)
			DECLARE @Id_Udc_Dettaglio					INT
			DECLARE @Uso_Modula							BIT = 0
			
			DECLARE @Qta_Dettaglio_Occupate	TABLE	(
														Id_UdcDettaglio		INT				NOT NULL,
														Qta_Impegnata		NUMERIC(10,2)	NOT NULL
													)
			DECLARE @Quantita_Impegnate TABLE	(
													Id_Udc			INT					NOT NULL,
													Id_Articolo		INT					NOT NULL,
													Qta_Impegnata	NUMERIC(10,2)		NOT NULL
												)
			
			DECLARE @Id_UdcDettaglio				INT
			DECLARE @Id_Udc							INT
			DECLARE @Disponibilita_Automha			NUMERIC(10,2)
			DECLARE @Qta_DaPrelevare_Automha		NUMERIC(10,2)
			DECLARE @Id_Tipo_Udc					VARCHAR(1)
			DECLARE @Id_Partizione_Dest_Missione	INT

			--Con questo flag tengo conto se per una determinata Udc e UdcDettaglio la quantità richiesta dalla lista la deve far svuotare completamente
			DECLARE @Flag_Svuota_Compl				BIT

			DECLARE CursoreLinee CURSOR LOCAL FAST_FORWARD FOR
				SELECT	ID,
						LINE_ID,
						ITEM_CODE,
						PROD_ORDER,
						QUANTITY,
						
						CASE
							WHEN @Order_Type = 'PXP' THEN CAST(BEHMG AS VARCHAR(MAX))
							ELSE COMM_PROD
						END						COMM_PROD,
						CASE
							WHEN @Order_Type = 'PXP' THEN CAST(PKBHT AS VARCHAR(MAX))
							ELSE COMM_SALE
						END						COMM_SALE,
						CASE
							WHEN @Order_Type = 'PXP' THEN ABLAD
							ELSE PROD_LINE
						END						PROD_LINE,

						ISNULL(KIT_ID,0),
						CASE
							WHEN ISNULL(Vincolo_WBS,0) = 1 THEN WBS_Riferimento
							ELSE NULL
						END,
						CASE
							WHEN ISNULL(Magazzino,'') = '0020' THEN 1
							ELSE 0
						END,
						Motivo_Nc
				FROM	Custom.RigheListePrelievo
				WHERE	ISNULL(STATO,0) = 0
					AND Id_Testata = @ID
				ORDER
					BY	LINE_ID, QUANTITY ASC

			OPEN CursoreLinee
			FETCH NEXT FROM CursoreLinee INTO
				@Id_Riga_C,
				@Line_Id_C,
				@Item_Code_C,
				@Prod_Order_C,
				@Quantity_C,
				@Comm_Prod_C,
				@Comm_Sale_Riga_C,
				@Prod_Line_C,
				@Kit_Id_C,
				@WBS_Riferimento_C,
				@Magazzino_NC_C,
				@Motivo_NC_C

			--Per ogni  riga di prelievo
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @Id_Articolo = NULL
				SET @Id_Udc_Dettaglio = 0
				SET @Quantita_Presente_Modula = 0
				
				SET @Quantita_Distribuita = 0
				SET @Disponibilita_Effettiva_Modula = 0
				SET @Quantita_Impegnata_Modula = 0

				SELECT	@Id_Articolo = Id_Articolo
				FROM	dbo.Articoli
				WHERE	Codice = @Item_Code_C

				IF @Id_Articolo IS NULL
					THROW 50008, 'ID ARTICOLO NELLA RIGA DI PRELIEVO NON PRESENTE IN ANAGRAFICA',1

				IF @Magazzino_NC_C = 1
				BEGIN
					EXEC [dbo].[sp_Prelievo_Lista_NC]
							@Id_Articolo			= @Id_Articolo,
							@Id_Partizione			= @Id_Partizione,
							@QTA_Richiesta			= @Quantity_C,
							@Id_Testata				= @ID,
							@Id_Riga				= @Id_Riga_C,
							@Kit_ID					= @Kit_Id_C,
							@QTA_Selezionata		= @Quantita_Distribuita		OUTPUT,
							@WBS_Riferimento_C		= @WBS_Riferimento_C,
							@MOTIVO_NC				= @MOTIVO_NC_C,
							@Id_Processo			= @Id_Processo,
							@Origine_Log			= @Origine_Log,
							@Id_Utente				= @Id_Utente,
							@Errore					= @Errore					OUTPUT
				END
				ELSE
				BEGIN
					--Controllo la disponibilità dell'articolo in modula e le quantità impegnate in modula
					SELECT	@Id_Udc_Dettaglio = ISNULL(Id_UdcDettaglio, -1),
							@Quantita_Presente_Modula = ISNULL(Quantita_Pezzi,0)
					FROM	dbo.Udc_Dettaglio
					WHERE	Id_Udc = @ID_UDC_MODULA
						AND Id_Articolo = @Id_Articolo

					--Per recuperare le quantità impegnate di un articolo già in lista di uscita consulto la lista di prelievo MISSIONI IN STATO 2
					SELECT	@Quantita_Impegnata_Modula = SUM(Quantita)
					FROM	dbo.Missioni_Picking_Dettaglio
					WHERE	Id_Stato_Missione = 2
						AND Id_Udc = @ID_UDC_MODULA
						AND Id_Articolo = @Id_Articolo
					GROUP
						BY	Id_Articolo,
							Id_Udc

					SET @Disponibilita_Effettiva_Modula = @Quantita_Presente_Modula - ISNULL(@Quantita_Impegnata_Modula,0)
					
					--VALUTO DI AVER QUALCOSA IN MODULA E SETTO QUANTO USO DI QUELLO
					--Per recuperare le quantità impegnate di un articolo già in lista di uscita consulto la lista di prelievo
					IF	@Disponibilita_Effettiva_Modula > 0
							AND
						@Id_Udc_Dettaglio <> -1
							AND
						--NON CONSIDERO MODULA NEI CASI IN CUI ABBIA UNA WBS DI RIFERIMENTO
						ISNULL(@WBS_Riferimento_C,'') = ''
					BEGIN
					--Se la disponibilità per l'articolo in modula è maggiore rispetto alla richiesta
						IF @Disponibilita_Effettiva_Modula >= @Quantity_C
						BEGIN
							--Inserisco nella Missioni dettaglio
							IF	EXISTS
								(
									SELECT	1
									FROM	dbo.Missioni_Picking_Dettaglio
									WHERE	Id_Testata_Lista = @ID
										AND Id_Riga_Lista = @Id_Riga_C
										AND Id_Udc = @ID_UDC_MODULA
										AND Id_UdcDettaglio = @Id_Udc_Dettaglio
										AND ISNULL(KIT_ID,0) = @Kit_Id_C
										AND Id_Stato_Missione = 4
								)
								UPDATE	dbo.Missioni_Picking_Dettaglio
								SET		Quantita += @Quantity_C,
										Id_Stato_Missione = 2,
										Flag_SvuotaComplet = 0,
										DataOra_UltimaModifica = GETDATE()
								WHERE	Id_Testata_Lista = @ID
									AND Id_Riga_Lista = @Id_Riga_C
									AND Id_Udc = @ID_UDC_MODULA
									AND Id_UdcDettaglio = @Id_Udc_Dettaglio
									AND ISNULL(KIT_ID,0) = @Kit_Id_C
									AND Id_Stato_Missione = 4
							ELSE
								INSERT INTO dbo.Missioni_Picking_Dettaglio
									(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Kit_Id, Id_Stato_Missione, DataOra_UltimaModifica)
								VALUES
									(@ID_UDC_MODULA,@Id_Udc_Dettaglio, @ID, @Id_Riga_C, @Id_Articolo, @Quantity_C, 0, @Kit_Id_C, 2,GETDATE())

							IF EXISTS
							(
								SELECT	TOP 1 1
								FROM	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
								WHERE	order_id = @Order_Id 
									AND item_code = @Item_Code_C
									AND prod_order_line_id = CONCAT(ISNULL(@Prod_Order_C, 'NOTDEFINED'),'_',@Line_Id_C, '_', ISNULL(@Kit_Id_C, '0'))
							)
							BEGIN
								SET XACT_ABORT ON
								UPDATE	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
								SET		quantity += @Quantity_C
								WHERE	order_id = @Order_Id 
									AND	item_code = @Item_Code_C
									AND	prod_order_line_id = CONCAT(ISNULL(@Prod_Order_C, 'NOTDEFINED'),'_',@Line_Id_C, '_', ISNULL(@Kit_Id_C, '0'))
								SET XACT_ABORT OFF
							END
							ELSE
							BEGIN
								SET XACT_ABORT ON
								INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
								VALUES (@Order_Id, @Item_Code_C, CONCAT(ISNULL(@Prod_Order_C, 'NOTDEFINED'),'_',@Line_Id_C, '_', ISNULL(@Kit_Id_C, '0')) ,
											@Quantity_C, @Order_Type, ISNULL(@Comm_Prod_C, ' '), ISNULL(@Comm_Sale_Riga_C, ' '), @Prod_Line_C, '');					
								SET XACT_ABORT OFF
							END
						
							SET @Quantita_Distribuita += @Quantity_C
						END
						ELSE
						--Se ho meno disponibilità di quanto richiesto inserisco tutta la quantità
						BEGIN
							IF EXISTS
							(
								SELECT	1
								FROM	dbo.Missioni_Picking_Dettaglio
								WHERE	Id_Testata_Lista = @ID
									AND Id_Riga_Lista = @Id_Riga_C
									AND Id_Udc = @ID_UDC_MODULA
									AND Id_UdcDettaglio = @Id_Udc_Dettaglio
									AND ISNULL(KIT_ID,0) = @Kit_Id_C
									AND Id_Stato_Missione = 4
							)
							UPDATE	dbo.Missioni_Picking_Dettaglio
							SET		Quantita += @Disponibilita_Effettiva_Modula,
									Id_Stato_Missione = 2,
									Flag_SvuotaComplet = 0,
									DataOra_UltimaModifica = GETDATE()
							WHERE	Id_Testata_Lista = @ID
								AND Id_Riga_Lista = @Id_Riga_C
								AND Id_Udc = @ID_UDC_MODULA
								AND Id_UdcDettaglio = @Id_Udc_Dettaglio
								AND ISNULL(KIT_ID,0) = @Kit_Id_C
								AND Id_Stato_Missione = 4
							ELSE
							INSERT INTO Missioni_Picking_Dettaglio
								(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Kit_Id, Id_Stato_Missione, DataOra_UltimaModifica)
							VALUES
								(@ID_UDC_MODULA,@Id_Udc_Dettaglio, @ID, @Id_Riga_C, @Id_Articolo, @Disponibilita_Effettiva_Modula, 0, @Kit_Id_C, 2, GETDATE())

							IF EXISTS	(
											SELECT	TOP 1 1
											FROM	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
											WHERE	order_id = @Order_Id 
												AND item_code = @Item_Code_C
												AND prod_order_line_id = CONCAT(ISNULL(@Prod_Order_C, 'NOTDEFINED'),'_',@Line_Id_C, '_', ISNULL(@Kit_Id_C, '0'))
										)
							BEGIN
								SET XACT_ABORT ON
								UPDATE	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
								SET		quantity += @Disponibilita_Effettiva_Modula
								WHERE	order_id = @Order_Id
									AND	item_code = @Item_Code_C
									AND	prod_order_line_id = CONCAT(ISNULL(@Prod_Order_C, 'NOTDEFINED'),'_',@Line_Id_C, '_', ISNULL(@Kit_Id_C, '0'))
								SET XACT_ABORT OFF
							END
							ELSE
							BEGIN
								SET XACT_ABORT ON
								INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
								VALUES (@Order_Id, @Item_Code_C, CONCAT(ISNULL(@Prod_Order_C, 'NOTDEFINED'),'_', @Line_Id_C, '_', ISNULL(@Kit_Id_C, '0')) ,
											@Disponibilita_Effettiva_Modula, @Order_Type, ISNULL(@Comm_Prod_C,' '), ISNULL(@Comm_Sale_Riga_C, ' '), @Prod_Line_C, '');
								SET XACT_ABORT OFF
							END

							SET @Quantita_Distribuita += @Disponibilita_Effettiva_Modula
						END
						--Utilizzo questa variabile per inserire successivamente la testata (altrimenti modula non interpreta i dati)
						SET @Uso_Modula = 1
					END

					SELECT @Item_Code_C, @Disponibilita_Effettiva_ModulA,@Quantita_Distribuita

					--SE MODULA NON E' SUFFICIENTE PROCEDO E VERIFICO IN AWM QUANTO HO
					IF @Quantita_Distribuita < @Quantity_C
					BEGIN
						SET @Id_UdcDettaglio				= NULL
						SET @Id_Udc							= NULL
						SET @Disponibilita_Automha			= 0
						SET @Id_Tipo_Udc					= ''

						SET @Flag_Svuota_Compl				= 0
						SET @Qta_DaPrelevare_Automha		= 0
						SET @Id_Partizione_Dest_Missione	= 0
						--Con questo flag tengo conto se per una determinata Udc e UdcDettaglio la quantità richiesta dalla lista la deve far svuotare completamente
					
						DELETE @Qta_Dettaglio_Occupate
						DELETE @Quantita_Impegnate

						INSERT INTO @Quantita_Impegnate
							SELECT	Id_Udc,
									Id_Articolo,
									SUM(Quantita)	Qta_Impegnata
							FROM	dbo.Missioni_Picking_Dettaglio
							WHERE	Id_Stato_Missione IN (1,2)
							GROUP
								BY	Id_Udc,
									Id_Articolo

						INSERT INTO @Qta_Dettaglio_Occupate
							SELECT	Id_UdcDettaglio,
									SUM(Quantita)	Qta_Impegnata
							FROM	Custom.ControlloQualita
							GROUP
								BY	Id_UdcDettaglio
							UNION
							SELECT	Id_UdcDettaglio,
									SUM(Quantita)	Qta_Impegnata
							FROM	Custom.NonConformita
							GROUP
								BY	Id_UdcDettaglio

						--Scorro le Udc contenenti quel codice articolo
						DECLARE CursoreUdc CURSOR LOCAL FORWARD_ONLY FOR
							SELECT	UD.Id_UdcDettaglio,
									UD.Id_Udc,
									--UD.Quantita_Pezzi - ISNULL(QI.Qta_Impegnata,0) - ISNULL(QD.Qta_Impegnata, 0) - ISNULL(QD.Qta_Impegnata, 0)	QuantitaUdc,
									UD.Quantita_Pezzi - ISNULL(QI.Qta_Impegnata,0) - ISNULL(QD.Qta_Impegnata, 0)	QuantitaUdc,
									UT.Id_Tipo_Udc
							FROM	dbo.Udc_Dettaglio				UD
							JOIN	dbo.Udc_Testata					UT
							ON		UT.Id_Udc = UD.Id_Udc
								AND UD.Id_Articolo = @Id_Articolo
								AND UD.Id_Udc <> @ID_UDC_MODULA
								AND ISNULL(UT.Blocco_Udc,0) = 0
								AND ISNULL(UD.WBS_Riferimento,'') = ISNULL(@WBS_Riferimento_C,'')
							JOIN	dbo.Udc_Posizione				UP
							ON		UP.Id_Udc = UD.Id_Udc
							JOIN	dbo.Partizioni					P
							ON		P.Id_Partizione = UP.Id_Partizione
								--Esludo le udc in area a terra, in uscita o in area packing list perchè non sono utilizzabili
								AND P.ID_TIPO_PARTIZIONE NOT IN ('AT', 'KT', 'AP', 'US', 'OO')
							--Quantità impegnate in altre liste gestite dalla Missioni_Picking_Dettaglio
							LEFT
							JOIN	@Quantita_Impegnate			QI
							ON		QI.Id_Udc = UD.Id_Udc
								AND QI.Id_Articolo = UD.Id_Articolo
							--Escludo le quantita in controllo qualità
							LEFT
							JOIN	@Qta_Dettaglio_Occupate		QD
							ON		QD.Id_UdcDettaglio = UD.Id_UdcDettaglio
							LEFT
							JOIN	dbo.Missioni_Picking_Dettaglio	MPD
							ON		MPD.Id_Udc = UD.Id_Udc
								AND MPD.Id_Stato_Missione IN (1,2)
							LEFT
							JOIN	Custom.OrdineKittingUdc		OKU
							ON		OKU.Id_Udc = UT.Id_Udc
							WHERE	1 = 1
								--Escludo tutte le udc coinvolte in una missione di kitting 
								AND ISNULL(OKU.Stato_Udc_Kit, 0) = 0
								--ESCLUDO TUTTI I DETTAGLI CON WBS DIVERSE DALLA MIA
								--ESCLUDO ANCHE LA QUANTITA CHE DEVE ESSERE CONTROLLATA
								AND UD.Quantita_Pezzi - ISNULL(QI.Qta_Impegnata,0) - ISNULL(QD.Qta_Impegnata, 0) > 0
							GROUP
								BY	UD.Id_UdcDettaglio,
									UD.Id_Udc,
									UD.Quantita_Pezzi,
									ISNULL(QI.Qta_Impegnata,0),
									ISNULL(QD.Qta_Impegnata,0),
									UT.Id_Tipo_Udc,
									UD.Data_Creazione,
									UT.Data_Inserimento
							ORDER
								BY	ISNULL(QD.Qta_Impegnata, 0)	ASC,--PRIMA CERCO DI ESTRARRE PIU' UDC CORRETTE
									UD.Data_Creazione			DESC,
									UT.Data_Inserimento			DESC,
									UD.Quantita_Pezzi			DESC

						OPEN CursoreUdc 
						FETCH NEXT FROM CursoreUdc  INTO
								@Id_UdcDettaglio,
								@Id_Udc,
								@Disponibilita_Automha,
								@Id_Tipo_Udc

						WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @Flag_Svuota_Compl				= 0
							SET @Qta_DaPrelevare_Automha		= 0
							SET @Id_Partizione_Dest_Missione	=	CASE
																		--Se è di tipo A lo mando alla baia da cui mi arriva la richiesta
																		WHEN @Id_Tipo_Udc IN ('1','2','3','I') THEN @Id_Partizione
																		--Se  è di tipo B lo mando alla baia 3B03
																		WHEN @Id_Tipo_Udc IN ('4','5','6') THEN 3203
																	END

							--Se per quell'Udc ho più Articoli della dettaglio di quanti me ne servono non la svuoto completamente
							IF (@Quantita_Distribuita + @Disponibilita_Automha) > @Quantity_C
							BEGIN
								SET @Flag_Svuota_Compl = 0
								SET @Qta_DaPrelevare_Automha = @Quantity_C - @Quantita_Distribuita

								--Inserisco nelle missioni dettaglio
								IF EXISTS (	SELECT	TOP 1 1 FROM Missioni_Picking_Dettaglio
											WHERE	Id_Testata_Lista = @ID AND Id_Riga_Lista = @Id_Riga_C
												AND Id_Udc = @Id_Udc AND Id_UdcDettaglio = @Id_UdcDettaglio
												AND ISNULL(KIT_ID,0) = @Kit_Id_C AND Id_Stato_Missione = 4)
									UPDATE	Missioni_Picking_Dettaglio
									SET		Quantita += @Quantity_C,
											Id_Stato_Missione = 1,
											Id_Partizione_Destinazione = @Id_Partizione_Dest_Missione,
											Flag_SvuotaComplet = @Flag_Svuota_Compl,
											DataOra_UltimaModifica = GETDATE()
									WHERE	Id_Testata_Lista = @ID
										AND Id_Riga_Lista = @Id_Riga_C
										AND Id_Udc = @Id_Udc AND Id_UdcDettaglio = @Id_UdcDettaglio
										AND ISNULL(KIT_ID,0) = @Kit_Id_C AND Id_Stato_Missione = 4
								ELSE
									INSERT INTO Missioni_Picking_Dettaglio
										(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Id_Stato_Missione,Id_Partizione_Destinazione, Kit_Id, DataOra_UltimaModifica)
									VALUES
										(@Id_Udc,@Id_UdcDettaglio,@ID, @Id_Riga_C, @Id_Articolo,@Qta_DaPrelevare_Automha,@Flag_Svuota_Compl, (CASE WHEN (@Id_Tipo_Udc = 'I') THEN 2 ELSE 1 END), @Id_Partizione_Dest_Missione, @Kit_Id_C, GETDATE())

								SET @Quantita_Distribuita = @Quantity_C
							END
							--Se l'udc non basta per soddisfare la quantità richiesta
							ELSE
							BEGIN
								SET @Flag_Svuota_Compl = 1
								SET @Quantita_Distribuita += @Disponibilita_Automha

								IF EXISTS (	SELECT	TOP 1 1 FROM Missioni_Picking_Dettaglio
											WHERE	Id_Testata_Lista = @ID AND Id_Riga_Lista = @Id_Riga_C
												AND Id_Udc = @Id_Udc AND Id_UdcDettaglio = @Id_UdcDettaglio
												AND ISNULL(KIT_ID,0) = @Kit_Id_C AND Id_Stato_Missione = 4)
									UPDATE	Missioni_Picking_Dettaglio
									SET		Quantita += @Disponibilita_Automha,
											Id_Stato_Missione = 1,
											Id_Partizione_Destinazione = @Id_Partizione_Dest_Missione,
											Flag_SvuotaComplet = @Flag_Svuota_Compl,
											DataOra_UltimaModifica = GETDATE()
									WHERE	Id_Testata_Lista = @ID
										AND Id_Riga_Lista = @Id_Riga_C
										AND Id_Udc = @Id_Udc AND Id_UdcDettaglio = @Id_UdcDettaglio
										AND ISNULL(KIT_ID,0) = @Kit_Id_C AND Id_Stato_Missione = 4
								ELSE
									INSERT INTO Missioni_Picking_Dettaglio
										(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Id_Stato_Missione, Id_Partizione_Destinazione, Kit_Id, DataOra_UltimaModifica)
									VALUES
										(@Id_Udc,@Id_UdcDettaglio,@ID, @Id_Riga_C, @Id_Articolo,@Disponibilita_Automha,@Flag_Svuota_Compl,(CASE WHEN (@Id_Tipo_Udc = 'I') THEN 2 ELSE 1 END),@Id_Partizione_Dest_Missione, @Kit_Id_C, GETDATE())
							END

							--Se ho distribuito completamente 
							IF @Quantita_Distribuita = @Quantity_C
								BREAK;

							FETCH NEXT FROM CursoreUdc INTO
									@Id_UdcDettaglio,
									@Id_Udc,
									@Disponibilita_Automha,
									@Id_Tipo_Udc
						END

						CLOSE CursoreUdc
						IF CURSOR_STATUS('local','CursoreUdc')>=-1
							DEALLOCATE CursoreUdc
					END
				END

				--SE TRA MODULA E AWM NON HO ABBASTANZA MI FERMO PERCHE' I MANCANTI LI GESTISCE SAP
				IF @Quantity_C - @Quantita_Distribuita > 0
				BEGIN
					DECLARE @MESSAGGIO AS VARCHAR(MAX) = CONCAT('Quantità non sufficiente a magazzino per l''articolo ', @Item_Code_C, ' quantita disp ', @Quantita_Distribuita, 'richiesta ', @Quantity_C,
																	' riga ', @Id_Riga_C, ' LINE ID ', @Line_Id_C)
					;THROW 50009,@MESSAGGIO, 1
				END

				UPDATE	Custom.RigheListePrelievo
				SET		Stato = 2
				WHERE	Id_Testata = @ID
					AND ID = @Id_Riga_C

				FETCH NEXT FROM CursoreLinee INTO
					@Id_Riga_C,
					@Line_Id_C,
					@Item_Code_C,
					@Prod_Order_C,
					@Quantity_C,
					@Comm_Prod_C,
					@Comm_Sale_Riga_C,
					@Prod_Line_C,
					@Kit_Id_C,
					@WBS_Riferimento_C,
					@Magazzino_NC_C,
					@Motivo_NC_C
			END

			CLOSE CursoreLinee
			DEALLOCATE CursoreLinee

			--Inserisco la testata  in modula
			IF (@Uso_Modula = 1)
			BEGIN
				SET XACT_ABORT ON
				----SMARCARE DETTAGLIO ETICHETTE
				INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_ORDERS
							([ORDER_ID]
							,[DES_PREL_CONF]
							,[ORD_TIPOOP]
							,[ORDER_TYPE]
							,[COMM_PROD]
							,[COMM_SALE]
							,[ITEM_COD_FIN]
							,[PROD_LINE]
							,[DETT_ETI])
						VALUES
							(@Order_Id, ISNULL(@Des_Prel_Conf,''), 'P', @Order_Type, ISNULL(@Comm_Prod_C, ''),
								ISNULL(@Comm_Sale_Testata, ''), ISNULL(@Item_Code_C_Fin, ''), ISNULL(@Prod_Line_Testata, ''), ISNULL(@Dett_Eti, ''))			
				SET XACT_ABORT OFF
			END

			IF @Quantita_Presente_Modula > 0
				SET @Errore = ISNULL(@ERRORE,'') + ' Quantita prelevate da modula'

			--Se tutto è andato a buon fine aggiorno lo stato testata lista in esecuzione
			UPDATE	Custom.TestataListePrelievo
			SET		Stato = 2
			WHERE	ID = @ID

			INSERT INTO [L3INTEGRATION].[dbo].[HOST_OUTGOING_SUMMARY]
				([DT_INS],[STATUS],[DT_ELAB],[USERNAME],[ORDER_ID],[ORDER_TYPE],[DT_EVASIONE],[COMM_PROD],[COMM_SALE],[DES_PREL_CONF],[ITEM_CODE_FIN],[FL_KIT],
					[NR_KIT],[PRIORITY],[PROD_LINE],[LINE_ID],[LINE_ID_ERP],[ITEM_CODE],[PROD_ORDER],[QUANTITY],[ACTUAL_QUANTITY],[FL_VOID],[SUB_ORDER_TYPE],[RAD],[PFIN],
					[DOC_NUMBER],[RETURN_DATE],[NOTES],[SAP_DOC_NUM],[KIT_ID],[ID_UDC],[RSPOS])
			SELECT	GETDATE(), 0, NULL, UPPER(@Id_Utente), ORDER_ID, ORDER_TYPE, ISNULL(DT_EVASIONE, ' '),
					ISNULL(COMM_PROD, ''),
					ISNULL(COMM_SALE,''),
					DES_PREL_CONF, ITEM_CODE_FIN, 0, NR_KIT, PRIORITY, PROD_LINE,99999,0,
					'',--rlp.ITEM_CODE,
					'',--rlp.PROD_ORDER,
					0,--rlp.QUANTITY,
					0,1, SUB_ORDER_TYPE, RAD, PFIN,
					NULL,NULL,NULL,'',--rlp.DOC_NUMBER, rlp.RETURN_DATE,NULL, rlp.SAP_DOC_NUM, 
					1, '',
					NULL--rlp.RSPOS
			FROM	Custom.TestataListePrelievo
			WHERE	ID = @ID

			--CONTROLLO SE NELLA LISTA SONO PRESENTI ESCLUSIVAMENTE MANCANTI 
			DECLARE @RecordCount	INT = 0
			DECLARE @CountMancanti	INT = 0
			
			SELECT	@RecordCount = COUNT(1)
			FROM	dbo.Missioni_Picking_Dettaglio
			WHERE	Id_Testata_Lista = @ID

			SELECT	@CountMancanti = COUNT(1)
			FROM	Custom.AnagraficaMancanti
			WHERE	Id_Testata = @ID

			IF	@RecordCount = 0
					AND
				@CountMancanti > 0
				UPDATE	Custom.TestataListePrelievo
				SET		Stato = 3
				WHERE	ID = @ID

			--CONTROLLO SE CI SONO COINVOLTE UDC INGOMBRANTI PER LANCIARE L'EVENTO DI PRELIEVO CUSTOM SULLA BAIA
			IF EXISTS(SELECT 1 FROM AwmConfig.vRighePrelievoAttive WHERE Id_Testata_Lista = @ID AND Nome_Magazzino IN ('INGOMBRANTI','INGOMBRANTI_M'))
			BEGIN
				--Se sono ingombranti le metto in stato 2 come per modula
				DECLARE @XmlParam			XML
				SET @XmlParam = CONCAT('<Parametri><Id_Testata_Lista>', @ID ,'</Id_Testata_Lista><Nome_Magazzino>INGOMBRANTI</Nome_Magazzino></Parametri>')
				SET @Errore += 'LISTA AVVIATA CORRETTAMENTE, ATTENZIONE!! '

				IF EXISTS (SELECT 1 FROM AwmConfig.vRighePrelievoAttive WHERE Id_Testata_Lista = @ID AND Nome_Magazzino = 'INGOMBRANTI')
				BEGIN
					--LANCIO UN EVENTO SULLA vRighePrelievoAttive per la lista avviata con destinazione ingombranti
					EXEC @Return = dbo.sp_Insert_Eventi
						@Id_Tipo_Evento		= 6,
						@Id_Partizione		= 7684,					--5A05
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore					OUTPUT;

					IF @Return <> 0 RAISERROR(@Errore,12,1)

					--NELL'EVENTO MOSTRO IL MESSAGGIO CUSTOM
					SET @Errore += 'LA LISTA PREVEDE PRELIEVO DI MATERIALI INGOMBRANTI'
				END

				IF EXISTS (SELECT 1 FROM AwmConfig.vRighePrelievoAttive WHERE Id_Testata_Lista = @ID AND Nome_Magazzino = 'INGOMBRANTI_M')
				BEGIN
					--LANCIO UN EVENTO SULLA vRighePrelievoAttive per la lista avviata con destinazione ingombranti
					EXEC @Return = dbo.sp_Insert_Eventi
						@Id_Tipo_Evento		= 6,
						@Id_Partizione		= 7685,					--5A05 - marcello
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore					OUTPUT;

					IF @Return <> 0 RAISERROR(@Errore,12,1)

					--NELL'EVENTO MOSTRO IL MESSAGGIO CUSTOM
					SET @Errore += 'LA LISTA PREVEDE PRELIEVO DI MATERIALI INGOMBRANTI PRESSO LA BAIA MARCELLO'
				END

			END

			--ALERT PER LE UDC DI TIPO B
			IF EXISTS(SELECT 1 FROM dbo.Missioni_Picking_Dettaglio WHERE Id_Testata_Lista = @ID AND Id_Partizione_Destinazione = 3203)
				SET @Errore += ' LA LISTA PREVEDE UDC DI TIPO B INVIATE IN 3B03'
		END
		--SE PROVENGO DA UNA LISTA SOSPESA LA RIMETTO IN STATO RUNNING
		ELSE IF (@Stato = 5)
		BEGIN 
			UPDATE	Custom.TestataListePrelievo
			SET		Stato = 2
			WHERE	ID = @ID
			
			--AGGIORNO LAPARTIZIONE DI DESTINAZIONE
			UPDATE	dbo.Missioni_Picking_Dettaglio
			SET		Id_Partizione_Destinazione = @Id_Partizione,
					DataOra_UltimaModifica = GETDATE()
			WHERE	Id_Testata_Lista = @ID
				AND Id_Stato_Missione = 1
				AND Id_Udc <> @ID_UDC_MODULA
			
			--SE HO UNA MISSIONE PICKING DETTAGLI IN STATO 2 MA NON C'E' LA MISSIONE ASSOCIATA LA RIMETTO IN STATO 1
			UPDATE	MPD
			SET		Id_Stato_Missione = 1,
					DataOra_UltimaModifica = GETDATE()
			FROM	dbo.Missioni_Picking_Dettaglio	MPD
			JOIN	dbo.Udc_Posizione				UP
			ON		up.Id_Udc = mpd.Id_Udc
			JOIN	dbo.Partizioni					P
			ON		p.ID_PARTIZIONE = up.Id_Partizione
				AND p.ID_TIPO_PARTIZIONE = 'MA'
			WHERE	MPD.Id_Testata_Lista = @ID
				AND MPD.Id_Stato_Missione = 5
				AND MPD.Id_Udc <> @ID_UDC_MODULA
				AND UP.Id_Partizione <> MPD.Id_Partizione_Destinazione
		END

		DECLARE @messaggio_log VARCHAR(MAX) = CONCAT('Tempo Impiegato ad avviare la lista ', @ID, ' ', DATEDIFF(MILLISECOND,@start,GETDATE()),' ms')
		EXEC dbo.sp_Insert_Log
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Proprieta_Log		= @Nome_StoredProcedure,
				@Id_Utente			= @Id_Utente,
				@Id_Tipo_Log		= 4,
				@Id_Tipo_Allerta	= 0,
				@Messaggio			= @messaggio_log,
				@Errore				= @Errore OUTPUT;
			
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

				EXEC dbo.sp_Insert_Log
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
