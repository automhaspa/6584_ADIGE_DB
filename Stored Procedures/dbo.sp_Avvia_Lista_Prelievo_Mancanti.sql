SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_Avvia_Lista_Prelievo_Mancanti]
	@Id_Testata		VARCHAR(MAX),
	@Id_Riga		INT,
	@Id_Partizione	INT				= NULL,
	-- Parametri Standard;
	@Id_Processo	VARCHAR(30),
	@Origine_Log	VARCHAR(25),
	@Id_Utente		VARCHAR(32),
	@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	--Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure	VARCHAR(30)
	DECLARE @TranCount				INT
	DECLARE @Return					INT
	DECLARE @ErrLog					VARCHAR(500)

	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure	= Object_Name(@@ProcId)
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount				= @@TRANCOUNT

	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		DECLARE @Start				DATETIME		= GETDATE()
		DECLARE @Msg_Finale			VARCHAR(MAX)	= ''
		DECLARE @Uso_Modula			BIT				= 0
		DECLARE @Qta_Distribuita	NUMERIC(18,4)	= 0

		DECLARE @Id_Articolo		INT
		DECLARE @Qta_DaPrelevare	NUMERIC(18,4)
		DECLARE @WBS_Riferimento	VARCHAR(40)
		DECLARE @Magazzino			VARCHAR(4)
		DECLARE @KIT_ID				INT
		
		SELECT	@Id_Articolo		=	AM.Id_Articolo,
				@Qta_DaPrelevare	=	AM.Qta_Mancante,
				@WBS_Riferimento	=	CASE
											WHEN ISNULL(RLP.Vincolo_WBS,0) = 1 THEN ISNULL(AM.WBS_Riferimento,RLP.WBS_RIFERIMENTO)
											ELSE NULL
										END,
				@Magazzino			=	CASE
											WHEN ISNULL(RLP.Magazzino,'') = '0020' THEN 1
											ELSE 0
										END,
				@KIT_ID				=	ISNULL(RLP.KIT_ID,0)
		FROM	Custom.AnagraficaMancanti		AM
		LEFT
		JOIN	Custom.RigheListePrelievo		RLP
		ON		RLP.ID = AM.Id_Riga
			AND RLP.Id_Testata = AM.Id_Testata
		WHERE	AM.Id_Testata = @Id_Testata
			AND AM.Id_Riga = @Id_Riga

		IF @Id_Partizione IS NULL
			THROW 50011, 'Partizione di destinazione lista non selezionata', 1
		
		DECLARE @Quantita_Impegnate TABLE	(
												Id_Udc			INT,
												Id_Articolo		INT,
												Qta_Impegnata	NUMERIC(10,2)
											)
		INSERT INTO @Quantita_Impegnate
			SELECT	Id_Udc,
					Id_Articolo,
					SUM(Quantita)	Qta_Impegnata
			FROM	Missioni_Picking_Dettaglio
			WHERE	Id_Stato_Missione IN (1,2)
			GROUP
				BY	Id_Udc,
					Id_Articolo

		DECLARE @Qta_Dettaglio_Occupate	TABLE	(
													Id_UdcDettaglio		INT,
													Qta_Impegnata		NUMERIC(10,2)
												)
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

		--Con questo flag tengo conto se per una determinata Udc e UdcDettaglio la quantità richiesta dalla lista la deve far svuotare completamente
		DECLARE @Flag_Svuota_Compl				BIT
		DECLARE @Id_UdcDettaglio				INT
		DECLARE @Qta_Dettaglio					INT
		DECLARE @Id_Udc							INT
		DECLARE @Id_Tipo_Udc					VARCHAR(1)
		DECLARE @Id_Partizione_Dest_Missione	INT

		IF @Magazzino = 1
			EXEC [dbo].[sp_Prelievo_Lista_NC]
				@Id_Articolo			= @Id_Articolo,
				@Id_Partizione			= @Id_Partizione,
				@QTA_Richiesta			= @Qta_DaPrelevare,
				@Id_Testata				= @Id_Testata,
				@Id_Riga				= @Id_Riga,
				@Kit_Id					= @KIT_ID,
				@QTA_Selezionata		= @Qta_Distribuita			OUTPUT,
				@WBS_Riferimento_C		= @WBS_Riferimento,
				@Id_Processo			= @Id_Processo,
				@Origine_Log			= @Origine_Log,
				@Id_Utente				= @Id_Utente,
				@Errore					= @Errore					OUTPUT
		ELSE
		BEGIN
			IF ISNULL(@WBS_Riferimento,'') = ''
			BEGIN
				WITH QTA_OCCUPATE_MODULA AS
				(
					SELECT	Id_UdcDettaglio,
							SUM(Quantita)		Quantita
					FROM	Missioni_Picking_Dettaglio
					WHERE	Id_Udc = 702
						AND Id_Stato_Missione <> 4
					GROUP
						BY	Id_UdcDettaglio
				)
				--Controllo la disponibilità dell'articolo in modula e le quantità impegnate in modula
				SELECT	@Id_UdcDettaglio = UD.Id_UdcDettaglio,
						@Qta_Dettaglio = ISNULL(Quantita_Pezzi,0) - ISNULL(QOM.Quantita,0)
				FROM	Udc_Dettaglio			UD
				LEFT
				JOIN	QTA_OCCUPATE_MODULA		QOM
				ON		QOM.Id_UdcDettaglio = UD.Id_UdcDettaglio
				WHERE	Id_Udc = 702
					AND Id_Articolo = @Id_Articolo
			END

			SET @Qta_Dettaglio = 0
			--VALUTO DI AVER QUALCOSA IN MODULA E SETTO QUANTO USO DI QUELLO
			IF ISNULL(@Qta_Dettaglio,0) > 0
			BEGIN
				--Se la disponibilità per l'articolo in modula è maggiore rispetto alla richiesta
				IF @Qta_Dettaglio >= @Qta_DaPrelevare
				BEGIN
					--Inserisco nella Missioni dettaglio
					IF EXISTS	(
									SELECT	TOP 1 1
									FROM	Missioni_Picking_Dettaglio
									WHERE	Id_Testata_Lista = @Id_Testata
										AND Id_Riga_Lista = @Id_Riga
										AND Id_Udc = 702
										AND Id_UdcDettaglio = @Id_UdcDettaglio
										AND ISNULL(KIT_ID,0) = @KIT_ID
										AND Id_Stato_Missione = 4
								)
								UPDATE	Missioni_Picking_Dettaglio
								SET		Quantita += @Qta_DaPrelevare,
										Id_Stato_Missione = 2,
										Flag_SvuotaComplet = 0,
										DataOra_UltimaModifica = GETDATE()
								WHERE	Id_Testata_Lista = @Id_Testata
									AND Id_Riga_Lista = @Id_Riga
									AND Id_Udc = 702
									AND Id_UdcDettaglio = @Id_UdcDettaglio
									AND ISNULL(KIT_ID,0) = @Kit_Id
									AND Id_Stato_Missione = 4
					ELSE
						INSERT INTO Missioni_Picking_Dettaglio
							(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Kit_Id, Id_Stato_Missione,FL_MANCANTI,DataOra_UltimaModifica)
						VALUES
							(702,@Id_UdcDettaglio, @Id_Testata, @Id_Riga, @Id_Articolo, @Qta_DaPrelevare, 0, @Kit_Id, 2, 1, GETDATE())

					IF EXISTS	(
									SELECT	TOP 1 1
									FROM	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES	hol
									JOIN	Custom.AnagraficaMancanti	AM
									ON		AM.ORDER_ID = HOL.ORDER_ID
										AND HOL.prod_order_line_id = CONCAT(ISNULL(AM.Prod_Order, 'NOTDEFINED'),'_',AM.Id_Riga, '_', ISNULL(@Kit_Id, '0'))
										AND AM.Id_Testata = @Id_Testata
										AND AM.Id_Riga = @Id_Riga
									JOIN	Articoli					A
									ON		A.Id_Articolo = AM.ID_ARTICOLO
										AND HOL.item_code = A.Codice
								)
					BEGIN
						SET XACT_ABORT ON
						UPDATE	hol
						SET		quantity += @Qta_DaPrelevare
						FROM	MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES	hol
						JOIN	Custom.AnagraficaMancanti	AM
						ON		AM.ORDER_ID = HOL.ORDER_ID
							AND HOL.prod_order_line_id = CONCAT(ISNULL(AM.Prod_Order, 'NOTDEFINED'),'_',AM.Id_Riga, '_', ISNULL(@Kit_Id, '0'))
							AND AM.Id_Testata = @Id_Testata
							AND AM.Id_Riga = @Id_Riga
						JOIN	Articoli					A
						ON		A.Id_Articolo = AM.ID_ARTICOLO
							AND HOL.item_code = A.Codice
						SET XACT_ABORT OFF
					END
					ELSE
					BEGIN
						SET XACT_ABORT ON
						INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
						SELECT	AM.ORDER_ID, A.CODICE, CONCAT(ISNULL(AM.Prod_Order, 'NOTDEFINED'),'_',AM.Id_Riga, '_', ISNULL(@Kit_Id, '0')) ,
								@Qta_DaPrelevare,AM.ORDER_TYPE, ISNULL(AM.COMM_PROD, ''),ISNULL(AM.COMM_SALE, ''),ISNULL(AM.PROD_LINE, ''), ''
						FROM	Custom.AnagraficaMancanti	AM
						JOIN	Articoli					A
						ON		A.Id_Articolo = AM.ID_ARTICOLO
						WHERE	AM.Id_Testata = @Id_Testata
							AND AM.Id_Riga = @Id_Riga
						SET XACT_ABORT OFF
					END
						
					SET @Qta_Distribuita += @Qta_DaPrelevare
				END
				ELSE
				--Se ho meno disponibilità di quanto richiesto inserisco tutta la quantità
				BEGIN
					IF EXISTS	(
									SELECT	TOP 1 1
									FROM	Missioni_Picking_Dettaglio
									WHERE	Id_Testata_Lista = @Id_Testata
										AND Id_Riga_Lista = @Id_Riga
										AND Id_Udc = 702
										AND Id_UdcDettaglio = @Id_UdcDettaglio
										AND ISNULL(KIT_ID,0) = @Kit_Id
										AND Id_Stato_Missione = 4
								)
						UPDATE	Missioni_Picking_Dettaglio
						SET		Quantita += @Qta_Dettaglio,
								Id_Stato_Missione = 2,
								Flag_SvuotaComplet = 0,
								DataOra_UltimaModifica = GETDATE()
						WHERE	Id_Testata_Lista = @Id_Testata
							AND Id_Riga_Lista = @Id_Riga
							AND Id_Udc = 702
							AND Id_UdcDettaglio = @Id_UdcDettaglio
							AND ISNULL(KIT_ID,0) = @Kit_Id
							AND Id_Stato_Missione = 4
					ELSE
						INSERT INTO Missioni_Picking_Dettaglio
							(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Kit_Id, Id_Stato_Missione, FL_MANCANTI,DataOra_UltimaModifica)
						VALUES
							(702,@Id_UdcDettaglio, @Id_Testata, @Id_Riga, @Id_Articolo, @Qta_Dettaglio, 0, @Kit_Id, 2, 1, GETDATE())
						
					SET XACT_ABORT ON
					INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_LINES
					--VALUES (@Order_Id, @Item_Code_C, CONCAT(ISNULL(@Prod_Order_C, 'NOTDEFINED'),'_', @Line_Id_C, '_', ISNULL(@Kit_Id_C, '0')) ,
					--			@Disponibilita_Effettiva_Modula, @Order_Type, ISNULL(@Comm_Prod_C,' '), ISNULL(@Comm_Sale_Riga_C, ' '), @Prod_Line_C, '');
					SELECT	AM.ORDER_ID, A.CODICE, CONCAT(ISNULL(AM.Prod_Order, 'NOTDEFINED'),'_',AM.Id_Riga, '_', ISNULL(@Kit_Id, '0')) ,
							@QTA_DETTAGLIO,AM.ORDER_TYPE, ISNULL(AM.COMM_PROD, ''),ISNULL(AM.COMM_SALE, ''),ISNULL(AM.PROD_LINE, ''), ''
					FROM	Custom.AnagraficaMancanti	AM
					JOIN	Articoli					A
					ON		A.Id_Articolo = AM.ID_ARTICOLO
					WHERE	AM.Id_Testata = @Id_Testata
						AND AM.Id_Riga = @Id_Riga
					SET XACT_ABORT OFF
						
					SET @Qta_Distribuita += @Qta_Dettaglio
				END

				SET @Uso_Modula = 1
			END

			--SE MODULA NON E' SUFFICIENTE PROCEDO E VERIFICO IN AWM QUANTO HO
			IF @Qta_Distribuita < @Qta_DaPrelevare
			BEGIN
				--AZZERO I DATI
				SET @Id_UdcDettaglio				= NULL
				SET @Id_Udc							= NULL
				SET @Qta_Dettaglio					= 0
				SET @Id_Tipo_Udc					= ''
				SET @Flag_Svuota_Compl				= 0
				SET @Id_Partizione_Dest_Missione	= @Id_Partizione

				--Scorro le Udc contenenti quel codice articolo
				DECLARE CursoreUdc CURSOR LOCAL FORWARD_ONLY FOR
					SELECT	UD.Id_UdcDettaglio,
							UD.Id_Udc,
							UD.Quantita_Pezzi - ISNULL(QI.Qta_Impegnata,0) - ISNULL(QD.Qta_Impegnata, 0)	QuantitaUdc,
							UT.Id_Tipo_Udc
					FROM	Udc_Dettaglio				UD
					JOIN	Udc_Testata					UT
					ON		UT.Id_Udc = UD.Id_Udc
						AND UD.Id_Articolo = @Id_Articolo
						AND UD.Id_Udc <> 702
						AND ISNULL(UT.Blocco_Udc,0) = 0
						AND ISNULL(UD.WBS_Riferimento,'') = ISNULL(@WBS_Riferimento,'')
					JOIN	Udc_Posizione				UP
					ON		UP.Id_Udc = UD.Id_Udc
					JOIN	Partizioni					P
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
					JOIN	Missioni_Picking_Dettaglio	MPD
					ON		MPD.Id_Udc = UD.Id_Udc
						AND Id_Stato_Missione IN (1,2)
					LEFT
					JOIN	Custom.OrdineKittingUdc		OKU
					ON		OKU.Id_Udc = UT.Id_Udc
					WHERE	1 = 1
						--Escludo tutte le udc coinvolte in una missione di kitting 
						AND ISNULL(OKU.Stato_Udc_Kit, 0) = 0
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
							UT.Data_Inserimento--,
							--TA.Abilitato
					ORDER
						BY	ISNULL(QD.Qta_Impegnata, 0)	ASC,--PRIMA CERCO DI ESTRARRE PIU' UDC CORRETTE
							UD.Data_Creazione			DESC,
							UT.Data_Inserimento			DESC,
							UD.Quantita_Pezzi			DESC

				OPEN CursoreUdc 
				FETCH NEXT FROM CursoreUdc  INTO
						@Id_UdcDettaglio,
						@Id_Udc,
						@Qta_Dettaglio,
						@Id_Tipo_Udc

				WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @Flag_Svuota_Compl				= 0

					IF @Id_Tipo_Udc IN ('4','5','6')
						SET @Id_Partizione_Dest_Missione = 3203
					
					--Se per quell'Udc ho più Articoli della dettaglio di quanti me ne servono non la svuoto completamente
					IF (@Qta_Distribuita + @Qta_Dettaglio) > @Qta_DaPrelevare
					BEGIN
						SET @Flag_Svuota_Compl = 0
						SET @Qta_Dettaglio = @Qta_DaPrelevare - @Qta_Distribuita
							
						--Inserisco nelle missioni dettaglio
						IF EXISTS	(
										SELECT	TOP 1 1 FROM Missioni_Picking_Dettaglio
										WHERE	Id_Testata_Lista = @Id_Testata
											AND Id_Riga_Lista = @Id_Riga
											AND Id_Udc = @Id_Udc
											AND Id_UdcDettaglio = @Id_UdcDettaglio
											AND ISNULL(KIT_ID,0) = @Kit_Id
											AND Id_Stato_Missione = 4
									)
							UPDATE	Missioni_Picking_Dettaglio
							SET		Quantita += @Qta_Dettaglio,
									Id_Stato_Missione = 1,
									Id_Partizione_Destinazione = @Id_Partizione_Dest_Missione,
									Flag_SvuotaComplet = @Flag_Svuota_Compl,
									DataOra_UltimaModifica = GETDATE()
							WHERE	Id_Testata_Lista = @Id_Testata
								AND Id_Riga_Lista = @Id_Riga
								AND Id_Udc = @Id_Udc
								AND Id_UdcDettaglio = @Id_UdcDettaglio
								AND ISNULL(KIT_ID,0) = @Kit_Id
								AND Id_Stato_Missione = 4
						ELSE
							--Inserisco nelle missioni dettaglio
							INSERT INTO Missioni_Picking_Dettaglio
								(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Id_Stato_Missione,Id_Partizione_Destinazione, Kit_Id, FL_MANCANTI,DataOra_UltimaModifica)
							VALUES
								(@Id_Udc,@Id_UdcDettaglio,@Id_Testata, @Id_Riga, @Id_Articolo, @Qta_Dettaglio, @Flag_Svuota_Compl, (CASE WHEN (@Id_Tipo_Udc = 'I') THEN 2 ELSE 1 END), @Id_Partizione_Dest_Missione, @Kit_Id, 1, GETDATE())

						SET @Qta_Distribuita = @Qta_Dettaglio
					END
					--Se l'udc non basta per soddisfare la quantità richiesta
					ELSE
					BEGIN
						IF NOT EXISTS(SELECT TOP 1 1 FROM Udc_Dettaglio WHERE Id_Udc = @Id_Udc AND Id_UdcDettaglio <> @Id_UdcDettaglio)
							SET @Flag_Svuota_Compl = 1
						ELSE
							SET @Flag_Svuota_Compl = 0

						SET @Qta_Distribuita += @Qta_Dettaglio

						IF EXISTS	(
										SELECT	TOP 1 1 FROM Missioni_Picking_Dettaglio
										WHERE	Id_Testata_Lista = @Id_Testata
											AND Id_Riga_Lista = @Id_Riga
											AND Id_Udc = @Id_Udc
											AND Id_UdcDettaglio = @Id_UdcDettaglio
											AND ISNULL(KIT_ID,0) = @Kit_Id
											AND Id_Stato_Missione = 4
									)
							UPDATE	Missioni_Picking_Dettaglio
							SET		Quantita += @Qta_Dettaglio,
									Id_Stato_Missione = 1,
									Id_Partizione_Destinazione = @Id_Partizione_Dest_Missione,
									Flag_SvuotaComplet = @Flag_Svuota_Compl,
									DataOra_UltimaModifica = GETDATE()
							WHERE	Id_Testata_Lista = @Id_Testata
								AND Id_Riga_Lista = @Id_Riga
								AND Id_Udc = @Id_Udc
								AND Id_UdcDettaglio = @Id_UdcDettaglio
								AND ISNULL(KIT_ID,0) = @Kit_Id
								AND Id_Stato_Missione = 4
						ELSE
							INSERT INTO Missioni_Picking_Dettaglio
								(Id_Udc, Id_UdcDettaglio, Id_Testata_Lista, Id_Riga_Lista, Id_Articolo, Quantita, Flag_SvuotaComplet, Id_Stato_Missione, Id_Partizione_Destinazione, Kit_Id, FL_MANCANTI,DataOra_UltimaModifica)
							VALUES
								(@Id_Udc,@Id_UdcDettaglio,@Id_Testata, @Id_Riga, @Id_Articolo,@Qta_Dettaglio, @Flag_Svuota_Compl,(CASE WHEN (@Id_Tipo_Udc = 'I') THEN 2 ELSE 1 END),@Id_Partizione_Dest_Missione, @Kit_Id, 1, GETDATE())
					END

					--Se ho distribuito completamente
					IF @Qta_Distribuita = @Qta_DaPrelevare
						BREAK;

					FETCH NEXT FROM CursoreUdc INTO
							@Id_UdcDettaglio,
							@Id_Udc,
							@Qta_Dettaglio,
							@Id_Tipo_Udc
				END

				CLOSE CursoreUdc
				IF CURSOR_STATUS('local','CursoreUdc')>=-1
					DEALLOCATE CursoreUdc
			END
		END
		
		IF @Qta_DaPrelevare - @Qta_Distribuita <> 0
		BEGIN
			IF @Qta_DaPrelevare - @Qta_Distribuita > 0 AND @Qta_Distribuita > 0
				SET @Msg_Finale = CONCAT('Non c''è quantità sufficiente ad azzerare il mancante. Verrà prelevato: ',@Qta_Distribuita)
			ELSE
				THROW 50009, 'NON C''E'' QUANTITA'' DISPONIBILE PER L''ARTICOLO SELEZIONATO',1
		END

		--Inserisco la testata  in modula
		IF @Uso_Modula = 1
		BEGIN
			SET XACT_ABORT ON
			INSERT INTO MODULA.HOST_IMPEXP.dbo.HOST_OUTGOING_ORDERS
				([ORDER_ID],[DES_PREL_CONF],[ORD_TIPOOP],[ORDER_TYPE],[COMM_PROD],[COMM_SALE],[ITEM_COD_FIN],[PROD_LINE],[DETT_ETI])
			SELECT	AM.ORDER_ID, ISNULL(AM.RagSoc_Dest,''), 'P', AM.ORDER_TYPE, ISNULL(AM.COMM_PROD, ''),
					ISNULL(AM.COMM_SALE, ''), A.Descrizione, ISNULL(AM.PROD_LINE, ''), ''
			FROM	Custom.AnagraficaMancanti	AM
			JOIN	Articoli					A
			ON		A.Id_Articolo = AM.ID_ARTICOLO
			WHERE	AM.Id_Testata = @Id_Testata
				AND AM.Id_Riga = @Id_Riga

			SET XACT_ABORT OFF

			SET @Msg_Finale += ' Quantità prelevate da modula'
		END

		DECLARE @XmlParam XML = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Missione_Modula>',0,'</Missione_Modula></Parametri>');

		--CONTROLLO  SE CI SONO COINVOLTE UDC INGOMBRANTI PER LANCIARE L'EVENTO DI PRELIEVO CUSTOM SULLA BAIA 
		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Missioni_Picking_Dettaglio	MPD
						JOIN	Udc_Testata					UT
						ON		MPD.Id_Udc = UT.Id_Udc
						WHERE	MPD.Id_Testata_Lista = @Id_Testata
							AND MPD.Id_Riga_Lista = @Id_Riga
							AND UT.Id_Tipo_Udc = 'I'
					)
		BEGIN
			--LANCIO UN EVENTO SULLA vRighePrelievoAttive per la lista avviata con destinazione ingombranti
			EXEC @Return = sp_Insert_Eventi
						@Id_Tipo_Evento		= 36,
						@Id_Partizione		= 7684,				--5A05
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore			OUTPUT

			IF @Return <> 0
				RAISERROR(@Errore,12,1)

			--NELL'EVENTO MOSTRO IL MESSAGGIO CUSTOM
			SET @Msg_Finale += ' E'' PREVISTO IL PRELIEVO DI MATERIALI INGOMBRANTI'
		END

		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Missioni_Picking_Dettaglio	MPD
						JOIN	Udc_Testata					UT
						ON		MPD.Id_Udc = UT.Id_Udc
						WHERE	MPD.Id_Testata_Lista = @Id_Testata
							AND MPD.Id_Riga_Lista = @Id_Riga
							AND UT.Id_Tipo_Udc = 'M'
					)
		BEGIN
			--LANCIO UN EVENTO SULLA vRighePrelievoAttive per la lista avviata con destinazione ingombranti
			EXEC @Return = sp_Insert_Eventi
						@Id_Tipo_Evento		= 36,
						@Id_Partizione		= 7685,				--5A05
						@Id_Tipo_Messaggio	= 1100,
						@XmlMessage			= @XmlParam,
						@Id_Processo		= @Id_Processo,
						@Origine_Log		= @Origine_Log,
						@Id_Utente			= @Id_Utente,
						@Errore				= @Errore			OUTPUT

			IF @Return <> 0
				RAISERROR(@Errore,12,1)

			--NELL'EVENTO MOSTRO IL MESSAGGIO CUSTOM
			SET @Msg_Finale += ' E'' PREVISTO IL PRELIEVO DI MATERIALI INGOMBRANTI PRESSO LA BAIA MARCELLO'
		END

		SET @XmlParam = NULL

			--ALERT PER LE UDC DI TIPO B
		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Missioni_Picking_Dettaglio	MPD
						WHERE	Id_Testata_Lista = @Id_Testata
							AND Id_Riga_Lista = @Id_Riga
							AND Id_Partizione_Destinazione = 3203
					)
			SET @Msg_Finale += ' E'' PREVISTO L''UTILIZZO DI UDC DI TIPO B INVIATE IN 3B03'

		DECLARE @Messaggio_Log VARCHAR(MAX) = CONCAT('Tempo Impiegato ad avviare la lista MANCANTI ', @Id_Testata, ' ', @Id_Riga, DATEDIFF(MILLISECOND,@start,GETDATE()),' ms')
		EXEC sp_Insert_Log
				@Id_Processo		= @Id_Processo,
				@Origine_Log		= @Origine_Log,
				@Proprieta_Log		= @Nome_StoredProcedure,
				@Id_Utente			= @Id_Utente,
				@Id_Tipo_Log		= 4,
				@Id_Tipo_Allerta	= 0,
				@Messaggio			= @Messaggio_Log,
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
