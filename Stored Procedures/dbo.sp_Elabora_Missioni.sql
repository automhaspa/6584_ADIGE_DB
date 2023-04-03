SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Elabora_Missioni]
-- Parametri Standard;
@Id_Processo		VARCHAR(30)	
,@Origine_Log		VARCHAR(25)	
,@Id_Utente			VARCHAR(16)		
,@SavePoint			VARCHAR(32) = ''
,@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	EXEC sp_Elabora_Messaggi	@Id_Processo = @Id_Processo
								,@Origine_Log = @Origine_Log
								,@Id_Utente = @Id_Utente
								,@Errore = @Errore OUTPUT

	SET NOCOUNT ON
	SET XACT_ABORT OFF
	SET LOCK_TIMEOUT 10000

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
--	DECLARE @SavePoint Varchar(32)
	-- Settaggio del SavePoint univoco con nome procedura e id della nidificazione;
	SET @SavePoint = Object_Name(@@ProcId) + Convert(Varchar,@@NESTLEVEL)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	--SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	--IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Id_Missione					INT
		DECLARE	@Id_Partizione_Sorgente			INT
		DECLARE	@Id_Partizione_Destinazione		INT
		DECLARE @Xml_Param						VARCHAR(MAX)
		DECLARE @Cursore						CURSOR
		DECLARE @Id_udc							INT
		DECLARE @Id_Stato_Missione				VARCHAR(3)
		DECLARE @Id_Tipo_Cella_Sorgente			VARCHAR(2)
		DECLARE @Id_Componente_Destinazione		INT
		DECLARE @Id_Tipo_Cella_Destinazione		VARCHAR(2)
		DECLARE @Capienza_Cella_Destinazione	INT
		DECLARE @Capienza_Cella_Sorgente		INT
		DECLARE @Id_Gruppo_Lista				INT
		DECLARE @Id_Stato_Gruppo				INT
		DECLARE @Handling_Mode					INT
		DECLARE @Sequenza_Percorso				INT
		DECLARE @Id_Partizione_Macchina			INT
		DECLARE @Id_Componente_Macchina			INT
		DECLARE @Id_Componente_Sorgente			INT
		DECLARE @ID_SOTTOCOMPONENTE_SORG		INT
		DECLARE @Flag_Esecuzione_Passo			BIT
		DECLARE @Id_Partizione_Deposito			INT
		DECLARE @Id_SottoAreaDeposito			INT
		DECLARE @Id_Tipo_Missione				VARCHAR(3)
		DECLARE @Stored_Procedure				VARCHAR(50)
		DECLARE @Id_Tipo_Messaggio				VARCHAR(5)
		DECLARE @ID_TIPO_UDC					VARCHAR(1)
		DECLARE @ID_SOTTOAREA_SORG				INT
		DECLARE @QuotaDeposito					INT
		DECLARE @Direzione						VARCHAR(1)
		DECLARE @PROFONDITA_UDC					INT, @PROFONDITA_CELLA		INT
		DECLARE @CapacitaDeposito				INT, @QuotaDepositoDeposito INT
		DECLARE @Quota							INT
		declare @cod_abb_sorg					VARCHAR(4)
		DECLARE @QUOTAX							INT
		DECLARE @Handling_Mode_udc				INT
        DECLARE @DEST_FINALE					INT
		DECLARE @Id_Raggruppa_Udc				INT
		DECLARE @ID_PARTIZIONE_RICALCOLO		INT
		DECLARE @GroupedTasks		TABLE (Id_Raggruppa_Udc Int, Id_Missione Int, Id_Udc Int, Sequenza_Percorso Int, Id_Partizione_Sorgente int, Id_Tipo_Cella_Sorgente Varchar(2),
											Id_Partizione_Destinazione Int, Id_Tipo_Cella_Destinazione Varchar(2), Handling_Mode Int, Handling_Mode_udc INT, Quota INT, QUOTAX INT)

		DECLARE @Id_Partizione_Scambio_Dest		INT

		 --RICALCOLO POSIZIONI BLOCCATE
		SELECT	@ID_PARTIZIONE_RICALCOLO = UP.Id_Partizione
		FROM	Udc_Posizione		UP
		JOIN	dbo.Partizioni		PS		ON PS.ID_PARTIZIONE = UP.Id_Partizione
		JOIN	dbo.Missioni		M		ON M.Id_Udc = UP.Id_Udc
		JOIN	dbo.Percorso		PERC	ON PERC.Id_Percorso = M.Id_Missione AND PERC.Id_Partizione_Sorgente = PS.ID_PARTIZIONE
		JOIN	dbo.Partizioni		PD		ON PD.ID_PARTIZIONE = PERC.Id_Partizione_Destinazione
		WHERE	PS.ID_TIPO_PARTIZIONE = 'TR'
			AND PD.ID_TIPO_PARTIZIONE = 'MA'
			AND PD.LOCKED = 1

		IF @ID_PARTIZIONE_RICALCOLO IS NOT NULL
			EXEC dbo.sp_RicalcoloMissione
						@Id_Partizione	= @ID_PARTIZIONE_RICALCOLO,
		                @Id_Processo	= @Id_Processo,
		                @Origine_Log	= @Origine_Log,
		                @Id_Utente		= @Id_Utente,
		                @Errore			= @Errore			OUTPUT

		-- Carico nel cursore tutte le missioni da eseguire.
		SET @Cursore = CURSOR LOCAL FAST_FORWARD FOR
		SELECT	Id_Raggruppa_Udc
				,Id_Percorso
				,Id_Tipo_Missione		
				,T.Id_Udc
				,Id_Stato_Missione
				,Id_Partizione_Sorgente
				,Id_Componente_Sorgente
				,ID_SOTTOCOMPONENTE_SORGENTE
				,Id_Tipo_Cella_Sorgente
				,CAPIENZA_SORG
				,T.Id_Partizione_Destinazione
				,Id_Componente_Destinazione  
				,TIPO_DESTINAZIONE
				,CAPIENZA_DEST
				,T.Id_Gruppo_Lista
				,G.Id_Stato_Gruppo
				,ISNULL(T.HANDLINGINFO,1)
				,UT.Handling_Mode
				,Sequenza_Percorso
				,Stored_Procedure
				,T.Xml_Param
				,Id_Tipo_Messaggio
				,U.Id_Tipo_Udc
				,T.ID_SOTTOAREA_SORG
				,T.QuotaDeposito
				,T.Direzione
				,U.Larghezza
				,T.PROFONDITA PROFONDITACELLA
				,Id_Partizione_Deposito
				,Capienza_Deposito
				,Quota 
				,T.QuotaX
				,cod_abb_sorg
				,T.DEST_FINALE
		FROM	(
					SELECT	T.*,
							RowId_SorgDest_SottoArea = DENSE_RANK() OVER (PARTITION BY T.ID_SOTTOAREA_SORG,T.Id_Componente_Destinazione,T.Id_Componente_Deposito ORDER BY Priorita DESC, Id_Raggruppa_Udc ASC),
							RowId_SorgDest_Componenti = DENSE_RANK() OVER (PARTITION BY T.Id_Componente_Sorgente,T.Id_Componente_Destinazione,T.Id_Componente_Deposito ORDER BY Priorita DESC,Id_Raggruppa_Udc ASC),
							RowId_SorgDest_Partizione = DENSE_RANK() OVER (PARTITION BY T.Id_Partizione_Sorgente,T.Id_Partizione_Destinazione,T.ID_PARTIZIONE_DEPOSITO ORDER BY Priorita DESC,Id_Raggruppa_Udc ASC)
							FROM	(
										SELECT	T.*,
												SDEP.ID_COMPONENTE			ID_COMPONENTE_DEPOSITO,
												PDEP.ID_SOTTOCOMPONENTE		ID_SOTTOCOMPONENTE_DEPOSITO,
												PDEP.ID_PARTIZIONE			ID_PARTIZIONE_DEPOSITO,
												PDEP.CAPIENZA				CAPIENZA_DEPOSITO,
												(
													SELECT	COUNT(0)
													FROM	Udc_Posizione
													WHERE	ID_PARTIZIONE = PDEP.ID_PARTIZIONE
												)					DEPSTANDING,
												CASE
													WHEN TIPO_COMP_SORG = 'S' THEN QuotaUdcInScaffale
													WHEN TIPO_COMP_DEST = 'S' THEN QUOTAMISSIONE
													ELSE NULL
												END					Quota,
												CASE
													WHEN TIPO_COMP_SORG = 'S' THEN QuotaUdcInScaffaleX
													WHEN TIPO_COMP_DEST = 'S' THEN QUOTAMISSIONEX
													ELSE NULL
												END					QuotaX
										FROM	(
													SELECT	T.*,
															RowId_Sorg_SottoComponenti = DENSE_RANK() OVER (PARTITION BY ID_SOTTOCOMPONENTE_SORGENTE ORDER BY CODICE_ABB_SORG ASC)
													FROM	(
																SELECT	T.*,
																		M.Id_Udc,
																		ISNULL(M.Id_Raggruppa_Udc,T.Id_Percorso)											ID_RAGGRUPPA_UDC,
																		M.Id_Tipo_Missione,
																		M.Id_Stato_Missione,
																		M.Id_Gruppo_Lista,
																		MAX(M.QuotaDeposito) OVER (PARTITION BY ISNULL(M.Id_Raggruppa_Udc,T.Id_Percorso))	DEEPEST_INFEED,
																		MAX(M.Priorita) OVER (PARTITION BY ISNULL(M.Id_Raggruppa_Udc,T.Id_Percorso))		Priorita,
																		M.HANDLINGINFO,
																		M.QuotaDeposito																		QUOTAMISSIONE,
																		M.QUOTADEPOSITOX																	QUOTAMISSIONEX,
																		PS.ID_TIPO_PARTIZIONE																ID_TIPO_CELLA_SORGENTE,
																		PS.CAPIENZA																			CAPIENZA_SORG,
																		PS.CODICE_ABBREVIATO																cod_abb_sorg,
																		PS.ID_SOTTOCOMPONENTE																ID_SOTTOCOMPONENTE_SORGENTE,
																		SS.ID_COMPONENTE																	ID_COMPONENTE_SORGENTE,
																		CS.ID_SOTTOAREA																		ID_SOTTOAREA_SORG,
																		CS.ID_TIPO_COMPONENTE																TIPO_COMP_SORG,
																		min(UP.QuotaDeposito) over (partition by UP.id_partizione, id_raggruppa_Udc)		QuotaDeposito,
																		PD.PROFONDITA,
																		PD.CAPIENZA				CAPIENZA_DEST,
																		PD.ID_TIPO_PARTIZIONE	TIPO_DESTINAZIONE,
																		SD.ID_COMPONENTE		ID_COMPONENTE_DESTINAZIONE,
																		CD.ID_TIPO_COMPONENTE	TIPO_COMP_DEST,
																		CASE
																			-- TO DO: DIPENDE DALLA DIREZIONE
																			WHEN 'TR' IN (PS.ID_TIPO_PARTIZIONE,PD.ID_TIPO_PARTIZIONE) THEN ROW_NUMBER() OVER (PARTITION BY SS.ID_SOTTOCOMPONENTE ORDER BY PS.CODICE_ABBREVIATO ASC, UP.QuotaDeposito ASC)
																			ELSE PS.CODICE_ABBREVIATO
																		END																					CODICE_ABB_SORG,
																		UP.QuotaDeposito																	QuotaUdcInScaffale,
																		UP.QuotaDepositoX																	QuotaUdcInScaffaleX,
																		M.Id_Partizione_Destinazione														DEST_FINALE,
																		p.DESCRIZIONE																		DEST,
																		P.ID_SOTTOAREA																		SOTTOARA_DEST_FINALE,
																		p2.DESCRIZIONE																		SORG
																FROM	(
																			SELECT	*
																			FROM	(	
																						SELECT	Id_Percorso,
																								Sequenza_Percorso,
																								Id_Tipo_Stato_Percorso,
																								Id_Partizione_Sorgente,
																								Id_Partizione_Destinazione,
																								RowId_Sequenza_Percorso = ROW_NUMBER() OVER (PARTITION BY Id_Percorso ORDER BY Sequenza_Percorso ASC),
																								Stored_Procedure,
																								CONVERT(Varchar(MAX),Xml_Param)		Xml_Param,
																								Id_Tipo_Messaggio,
																								Direzione
																						FROM	Percorso
																						WHERE	Id_Tipo_Stato_Percorso IN (1,2)
																					)	T
																					WHERE T.RowId_Sequenza_Percorso = 1
																			)T
																			JOIN		Missioni M ON M.Id_Missione = T.Id_Percorso
																			LEFT JOIN	AwmConfig.vPartizioni P ON P.ID_PARTIZIONE = M.Id_Partizione_Destinazione
																			LEFT JOIN	dbo.Partizioni AS p2 ON p2.ID_PARTIZIONE = M.Id_Partizione_Sorgente
																			LEFT JOIN	Partizioni PS ON PS.Id_Partizione = T.Id_Partizione_Sorgente
																			LEFT JOIN	SottoComponenti SS ON SS.ID_SOTTOCOMPONENTE = PS.ID_SOTTOCOMPONENTE
																			LEFT JOIN	Componenti CS ON CS.ID_COMPONENTE = SS.ID_COMPONENTE
																			LEFT JOIN	Partizioni PD ON PD.Id_Partizione = T.Id_Partizione_Destinazione
																			LEFT JOIN	SottoComponenti SD ON SD.ID_SOTTOCOMPONENTE = PD.ID_SOTTOCOMPONENTE
																			LEFT JOIN	Componenti CD ON CD.ID_COMPONENTE = SD.ID_COMPONENTE
																			LEFT JOIN	Udc_Posizione UP ON UP.Id_Udc = M.Id_Udc
																			WHERE	Id_Tipo_Stato_Percorso = 1
																				AND (PD.ID_PARTIZIONE IS NULL OR (SELECT COUNT(0) FROM Udc_Posizione WHERE Id_Partizione = PD.ID_PARTIZIONE) <	CASE
																																																	WHEN PD.ID_TIPO_PARTIZIONE = 'TR' THEN 1
																																																	ELSE PD.CAPIENZA
																																																END)
																				AND (
																						(SD.ID_COMPONENTE NOT IN (34,35,36,37,38,39,40,41,42,43,44,45) OR SS.ID_COMPONENTE = SD.ID_COMPONENTE)
																							OR
																						NOT EXISTS	(
																										SELECT	Componenti.ID_COMPONENTE
																										FROM	dbo.Componenti
																										JOIN	dbo.SottoComponenti ON SottoComponenti.ID_COMPONENTE = Componenti.ID_COMPONENTE
																										JOIN	dbo.Partizioni ON Partizioni.ID_SOTTOCOMPONENTE = SottoComponenti.ID_SOTTOCOMPONENTE
																										JOIN	dbo.Udc_Posizione ON Udc_Posizione.Id_Partizione = Partizioni.ID_PARTIZIONE
																										WHERE	Componenti.ID_COMPONENTE = SD.ID_COMPONENTE
																									)
																					)
																				AND	ISNULL(PD.Locked,0) = 0	
																				AND ISNULL(PS.Locked,0) = 0
															)T
												)T	
										LEFT JOIN Partizioni PDEP ON ID_PARTIZIONE = (SELECT Id_Partizione_Destinazione FROM Percorso WHERE TIPO_DESTINAZIONE = 'TR'  AND Id_Percorso = T.Id_Percorso AND Sequenza_Percorso = T.Sequenza_Percorso + 1)
										LEFT JOIN SottoComponenti SDEP ON SDEP.ID_SOTTOCOMPONENTE = PDEP.ID_SOTTOCOMPONENTE
										WHERE	(RowId_Sorg_SottoComponenti = 1  OR ID_SOTTOCOMPONENTE_SORGENTE IS NULL)
									)	T
				)T
		INNER JOIN Udc_Testata U ON U.Id_Udc = T.Id_Udc		
		INNER JOIN Tipo_Udc UT ON UT.Id_Tipo_Udc = U.Id_Tipo_Udc
		LEFT JOIN Lista_Host_Gruppi G ON G.Id_Gruppo_Lista = T.Id_Gruppo_Lista
		WHERE	(RowId_SorgDest_Componenti = 1 OR Id_Componente_Sorgente IS NULL)
			AND (RowId_SorgDest_Partizione = 1 OR Id_Partizione_Sorgente IS NULL)
			AND (RowId_SorgDest_SottoArea = 1 OR ID_SOTTOAREA_SORG IS NULL)
			AND (
					ISNULL(TIPO_DESTINAZIONE,'') <> 'TR' 
					OR
					(
						(CAPIENZA_DEPOSITO IS NULL
							OR
						DEPSTANDING < CAPIENZA_DEPOSITO
							AND
						NOT EXISTS	(
										SELECT	TOP 1 1
										FROM	Udc_Posizione
										JOIN	Partizioni		ON	Partizioni.ID_PARTIZIONE = udc_posizione.id_partizione
										WHERE	ID_SOTTOCOMPONENTE = id_sottocomponente_deposito
											AND ID_TIPO_PARTIZIONE = 'RU'
									)
						)
					)
				)
		ORDER
			BY	T.Priorita DESC

		OPEN @Cursore	
			
		FETCH NEXT FROM @Cursore INTO
		@Id_Raggruppa_Udc
		,@Id_Missione
		,@Id_Tipo_Missione
		,@Id_Udc
		,@Id_Stato_Missione
		,@Id_Partizione_Sorgente
		,@Id_Componente_Sorgente
		,@ID_SOTTOCOMPONENTE_SORG
		,@Id_Tipo_Cella_Sorgente
		,@Capienza_Cella_Sorgente
		,@Id_Partizione_Destinazione
		,@Id_Componente_Destinazione
		,@Id_Tipo_Cella_Destinazione
		,@Capienza_Cella_Destinazione
		,@Id_Gruppo_Lista
		,@Id_Stato_Gruppo
		,@Handling_Mode
		,@Handling_Mode_udc
		,@Sequenza_Percorso
		,@Stored_Procedure
		,@Xml_Param
		,@Id_Tipo_Messaggio
		,@ID_TIPO_UDC
		,@ID_SOTTOAREA_SORG 
		,@QuotaDeposito 
		,@Direzione 
		,@PROFONDITA_UDC
		,@PROFONDITA_CELLA
		,@Id_Partizione_Deposito
		,@CapacitaDeposito
		,@Quota
		,@QUOTAX
		,@cod_abb_sorg
		,@DEST_FINALE

		WHILE @@FETCH_STATUS = 0
		BEGIN		
			BEGIN TRANSACTION
			
			IF @Stored_Procedure IS NOT NULL
			BEGIN
				UPDATE	Percorso
				SET		Id_Tipo_Stato_Percorso = 2
				WHERE	Sequenza_Percorso = @Sequenza_Percorso
					AND Id_Percorso = @Id_Missione

				-- Se quello ke devo eseguire è un'adiacenza composta, eseguo la stored procedure e metto il passo ad "esecuzione"
				EXEC @Return = @Stored_Procedure
							@Xml_Param			= @Xml_Param,
							@Id_Missione		= @Id_Missione,
							@Sequenza_Percorso	= @Sequenza_Percorso,
							@Id_udc				= @Id_udc,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore			OUTPUT

				IF @Return <> 0
					RAISERROR(@Errore,12,1)
			END
			-- Controllo le condizioni per mandare in esecuzione le missioni					
			ELSE IF (SELECT COUNT(0) FROM Percorso WHERE Id_Tipo_Stato_Percorso = 2 AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione) = 0 -- missioni doppie
						AND
					(SELECT COUNT(0) FROM Missioni WHERE Id_Udc = @Id_Udc AND Missioni.Id_Missione <> @Id_Missione AND Id_Stato_Missione = 'ESE') = 0
						AND
					(SELECT	COUNT(0) FROM Eventi WITH(READCOMMITTED) WHERE Id_Tipo_Stato_Evento = 1 AND Xml_Param.value('data(//Id_Udc)[1]','int') = @Id_Udc) = 0
			BEGIN
				IF @Id_Tipo_Cella_Sorgente = 'TR'
					SELECT	@Id_Partizione_Macchina = @Id_Partizione_Sorgente,
							@Id_Componente_Macchina = @Id_Componente_Sorgente

				ELSE IF @Id_Tipo_Cella_Destinazione = 'TR'
					SELECT	@Id_Partizione_Macchina = @Id_Partizione_Destinazione,
							@Id_Componente_Macchina = @Id_Componente_Destinazione

				IF @Id_Partizione_Macchina IS NULL
					SET @Flag_Esecuzione_Passo = 1
				ELSE
					IF	@Id_Partizione_Macchina IS NOT NULL
						AND
						(
							SELECT COUNT(0)
							FROM	Percorso
							WHERE	Id_Tipo_Stato_Percorso = 1
								AND Id_Componente_Prenotato = @Id_Componente_Macchina
								AND Id_Percorso <> @Id_Missione
						) = 0
				BEGIN
					IF EXISTS (SELECT TOP 1 1 FROM Udc_Posizione WHERE Id_Udc = @Id_Udc AND Id_Partizione = @Id_Partizione_Sorgente)
					BEGIN
						SET		@Id_Partizione_Scambio_Dest = NULL

						DECLARE @ID_UDC_SCAMBIO				INT = NULL
						DECLARE @PALLETQTY					INT = NULL
						DECLARE @COUNTMISS					INT = NULL
						DECLARE @QuotaSC					INT

						SELECT	@ID_UDC_SCAMBIO = Id_Udc,
								@COUNTMISS = (SELECT COUNT(0) FROM MISSIONI WHERE ID_STATO_MISSIONE IN ('NEW','ELA','ESE') AND ID_UDC = UP.ID_UDC)
						FROM	Udc_Posizione		UP
						JOIN	Partizioni			P
						ON		P.ID_PARTIZIONE = UP.Id_Partizione
						WHERE	ID_SOTTOCOMPONENTE = @ID_SOTTOCOMPONENTE_SORG
							AND P.CODICE_ABBREVIATO < @cod_abb_sorg
							AND ABS(QuotaDepositoX - @QUOTAX) <= 50
						ORDER
							BY	CODICE_ABBREVIATO DESC,
								QuotaDeposito DESC -- TO DO : ordinameno a seconda della direction

						-- Controllo le condizioni per comporre il GMOVE.
						IF	(
								SELECT	COUNT(0)
								FROM	Percorso
								JOIN	Partizioni			PS ON PS.Id_Partizione = Id_Partizione_Sorgente AND Id_Tipo_Stato_percorso = 2
								JOIN	SottoComponenti		SS ON SS.ID_SOTTOCOMPONENTE = PS.ID_SOTTOCOMPONENTE
								JOIN	Partizioni			PD ON PD.Id_Partizione = Id_Partizione_Destinazione AND Id_Tipo_Stato_percorso = 2
								JOIN	SottoComponenti		SD ON SD.ID_SOTTOCOMPONENTE = PD.ID_SOTTOCOMPONENTE
								WHERE	(SS.Id_Componente = @Id_Componente_Macchina)
									OR	(SD.Id_Componente = @Id_Componente_Macchina)
							) = 0
							AND @ID_UDC_SCAMBIO IS NULL
						BEGIN
							-- Se prima del GMove che posso eseguire ho un item event da fare
							-- sovrascrivo l'operazione da  eseguire con l'item event.
							SELECT	@Id_Tipo_Messaggio = Id_Tipo_Messaggio,
									@Sequenza_Percorso = Sequenza_Percorso,
									@Id_Partizione_Destinazione = Id_Partizione_Destinazione
							FROM	Percorso
							WHERE	Id_Percorso = @Id_Missione
								AND Sequenza_Percorso = @Sequenza_Percorso - 1
								AND Id_Tipo_Messaggio = '1219'
								AND Id_Tipo_Stato_Percorso = 1

							SET @Flag_Esecuzione_Passo = 1
						END
						ELSE IF @ID_UDC_SCAMBIO IS NOT NULL AND @COUNTMISS = 0
						BEGIN
							DECLARE @QUOTADEPOSITOX_DEST INT
							-- Lo sacaffale ha solo un'adiacenza, significa che può portare una sola Udc alla volta, quindi faccio la normale proposta d'ubicazione.
							-- Creo la proposta di ubicazione per la udc che devo spostare, con il Flag di scambio settato a uno per il confronto del @Tipo_Cella
							-- nella proposta di ubicazione
							DECLARE @ID_TIPO_MISSIONE_SCA VARCHAR(3) = 'SCA'
							BEGIN TRY
								EXEC @Id_Partizione_Scambio_Dest = sp_Output_PropostaUbicazione
											@Id_Udc				= @ID_UDC_SCAMBIO,
											@QUOTADEPOSITOX		= @QUOTADEPOSITOX_DEST	OUTPUT,
											@Id_Processo		= @Id_Processo,
											@Origine_Log		= @Origine_Log,
											@Id_Utente			= @Id_Utente,
											@Errore				= @Errore				OUTPUT
							END TRY
							BEGIN CATCH
								IF EXISTS (SELECT TOP 1 1 FROM Udc_Testata WHERE Id_Udc = @ID_UDC_SCAMBIO AND Id_Tipo_Udc IN ('4','5,','6'))
									SET @Id_Partizione_Scambio_Dest = 3203
								ELSE IF EXISTS(SELECT TOP 1 1 FROM Missioni_Picking_Dettaglio WHERE Id_Udc = @Id_udc AND Id_Stato_Missione IN (1,2))
									SELECT	@Id_Partizione_Scambio_Dest = TLP.Id_Partizione_Uscita
									FROM	Missioni_Picking_Dettaglio	MPD
									JOIN	Custom.TestataListePrelievo	TLP
									ON		TLP.ID = MPD.Id_Testata_Lista
										AND MPD.Id_Stato_Missione IN (1,2)
										AND MPD.Id_Udc = @Id_udc
									ORDER
										BY	MPD.Id_Stato_Missione

								IF ISNULL(@Id_Partizione_Scambio_Dest,0) = 0
									SET @Id_Partizione_Scambio_Dest = @DEST_FINALE

								SET @ID_TIPO_MISSIONE_SCA = 'OUT'
							END CATCH

							--IF @Id_Partizione_Scambio_Dest <> 3203
							--BEGIN
								EXEC @Return = sp_insert_CreaMissioni
											@Id_Udc							= @Id_Udc_Scambio,
											@priorita						= 99,
											@Id_Partizione_Destinazione		= @Id_Partizione_Scambio_Dest,
											@QUOTADEPOSITOX					= @QUOTADEPOSITOX_DEST,
											@Id_Tipo_Missione				= @ID_TIPO_MISSIONE_SCA,
											@Id_Processo					= @Id_Processo,
											@Origine_Log					= @Origine_Log,
											@Id_Utente						= @Id_Utente,
											@Errore							= @Errore				OUTPUT

								IF @Return <> 0 RAISERROR (@Errore, 12, 1)
							--END
						END
					END
				END
 							
				IF ISNULL(@Flag_Esecuzione_Passo,0) = 1
				BEGIN
					DECLARE @CURSORE_MESSAGGI CURSOR

					IF	@Id_Raggruppa_Udc IS NOT NULL
						AND
						(
							(@Id_Tipo_Cella_Sorgente = 'TR' AND @Capienza_Cella_Sorgente > 1)
								OR
							(@Id_Tipo_Cella_Destinazione = 'TR' AND @Capienza_Cella_Destinazione > 1)
						)
					BEGIN
						INSERT INTO @GroupedTasks
							(Id_Raggruppa_Udc, Id_Missione, Id_Udc, Sequenza_Percorso, Id_Partizione_Sorgente, Id_Tipo_Cella_Sorgente, Id_Partizione_Destinazione, Id_Tipo_Cella_Destinazione, Handling_Mode, Handling_Mode_udc, Quota, QUOTAX)
						VALUES
							(@Id_Raggruppa_Udc, @Id_Missione, @Id_Udc, @Sequenza_Percorso, @Id_Partizione_Sorgente, @Id_Tipo_Cella_Sorgente, @Id_Partizione_Destinazione, @Id_Tipo_Cella_Destinazione, @Handling_Mode, @Handling_Mode_udc, @Quota, @QUOTAX)

						SET @CURSORE_MESSAGGI = CURSOR LOCAL STATIC FOR
							SELECT 	Id_Udc, Id_Missione, Sequenza_Percorso, Id_Partizione_Sorgente, Id_Tipo_Cella_Sorgente, Id_Partizione_Destinazione, Id_Tipo_Cella_Destinazione, Handling_Mode, Handling_Mode_udc, Quota, QUOTAX
							FROM	@GroupedTasks 
							WHERE	Id_Raggruppa_Udc = @Id_Raggruppa_Udc
								AND (SELECT COUNT(0) FROM MISSIONI WHERE ID_RAGGRUPPA_UDC = @ID_RAGGRUPPA_UDC AND ID_MISSIONE NOT IN (SELECT ID_MISSIONE FROM @GroupedTasks)) = 0
							ORDER BY Quota DESC
					END
					ELSE
					BEGIN
						SET @CURSORE_MESSAGGI = CURSOR LOCAL STATIC FOR
							SELECT 	@Id_Udc, @Id_Missione, @Sequenza_Percorso, @Id_Partizione_Sorgente, @Id_Tipo_Cella_Sorgente, @Id_Partizione_Destinazione, @Id_Tipo_Cella_Destinazione,
									@Handling_Mode, @Handling_Mode_udc, @Quota, @QUOTAX
					END

					OPEN @CURSORE_MESSAGGI
					IF @@CURSOR_ROWS > 0
					BEGIN
						SET @Xml_Param = '<Parametri>'

						FETCH NEXT FROM @CURSORE_MESSAGGI INTO
							@Id_Udc
							,@Id_Missione
							,@Sequenza_Percorso
							,@Id_Partizione_Sorgente
							,@Id_Tipo_Cella_Sorgente
							,@Id_Partizione_Destinazione
							,@Id_Tipo_Cella_Destinazione
							,@Handling_Mode
							,@Handling_Mode_udc
							,@Quota
							,@QUOTAX

						WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @Id_Tipo_Messaggio = '12020'
							BEGIN
								SET @Xml_Param +=	'<LU_Itinerary Id_LU="' + CONVERT(Varchar,@Id_Udc)
													+ '" ID_COMPONENTE_SORGENTE="' + CONVERT(Varchar,@Id_Componente_Sorgente)
													+ '" Id_Partizione_Sorgente="' + CONVERT(Varchar,@Id_Partizione_Sorgente)
													+ '" Tipo_Partizione_Sorgente="' + @Id_Tipo_Cella_Sorgente
													+ '" ID_COMPONENTE_DESTINAZIONE="' + CONVERT(Varchar,@Id_Componente_Destinazione)
													+ '" Id_Partizione_Destinazione="' + CONVERT(Varchar,@Id_Partizione_Destinazione)
													+ '" Tipo_Partizione_Destinazione="' + @Id_Tipo_Cella_Destinazione
													+ '" Id_Missione="' + CONVERT(Varchar,@Id_Missione)
													+ '" Sequenza_Percorso="' + CONVERT(Varchar,@Sequenza_Percorso)
													+ '" Handling_Mode_udc="' + CONVERT(Varchar,@Handling_Mode_udc)
													+	CASE
															WHEN @Quota IS NOT NULL THEN '" Quota="' + CONVERT(Varchar,@Quota)
															ELSE ''
														END
													+ '"/>'
							END
							
							IF @Id_Stato_Missione = 'ELA'
							BEGIN
								EXEC @Return = sp_Update_Stato_Missioni
											@Id_Missione = @Id_Missione
											,@Id_Stato_Missione = 'ESE'
											,@Id_Processo = @Id_Processo
											,@Origine_Log = @Origine_Log
											,@Id_Utente = @Id_Utente
											,@Errore = @Errore OUTPUT

								IF @Return <> 0 RAISERROR(@Errore,12,1)

								IF ISNULL(@Id_Stato_Gruppo,5) <> 5
									UPDATE	Lista_Host_Gruppi
									SET		Id_Stato_Gruppo = 5
									WHERE	Id_Gruppo_Lista = @Id_Gruppo_Lista
							END

							UPDATE	Percorso
							SET		Id_Tipo_Stato_Percorso = 2
							WHERE	Sequenza_Percorso = @Sequenza_Percorso
								AND Id_Percorso = @Id_Missione

							FETCH NEXT FROM @CURSORE_MESSAGGI INTO
								@Id_Udc
								,@Id_Missione
								,@Sequenza_Percorso
								,@Id_Partizione_Sorgente
								,@Id_Tipo_Cella_Sorgente
								,@Id_Partizione_Destinazione
								,@Id_Tipo_Cella_Destinazione
								,@Handling_Mode
								,@Handling_Mode_udc
								,@Quota
								,@QUOTAX
						END

						IF @Id_Tipo_Messaggio = '12020'
						BEGIN
							SET @Xml_Param += '</Parametri>'

							-- ADIGE/SCOTTON
							-- OVERRIDE DELLA QUOTA X
							--SE HO COME DESTINAZIONE O SORGENTE UNA CELLA DI MAGAZZINO
							IF 'MA' IN (@Id_Tipo_Cella_Destinazione,@Id_Tipo_Cella_Sorgente)
							BEGIN
								--CONTROLLO IL TIPO DI UDC PER GENERARE UNA QUOTA COERENTE --> Se è un Udc di Tipo A ho 3 quote statiche -920/0/+920
								IF @ID_TIPO_UDC IN ('1','2','3')
								BEGIN
									DECLARE @Capienza	INT

									SET @QUOTAX =	CASE
														WHEN (@QUOTAX = 10)		THEN -920
														WHEN (@QUOTAX = 820)	THEN 0
														WHEN (@QUOTAX = 1630)	THEN +920
													END

									--CELLE DI CAPIENZA 1 CHE NECESSITANO QUOTA 0
									SELECT	@Capienza = CAPIENZA
									FROM	dbo.Partizioni
									WHERE	ID_PARTIZIONE = CASE
																WHEN @Id_Tipo_Cella_Destinazione = 'MA' THEN @Id_Partizione_Destinazione
																ELSE @Id_Partizione_Sorgente
															END

									IF @Capienza = 1
										SET @QUOTAX = 0
								END
								--SE E' DI TIPO B
								ELSE IF (@ID_TIPO_UDC IN ('4','5','6'))
									SET @QUOTAX = 0
							END
							ELSE
								SET @QUOTAX = NULL

							IF @QUOTAX IS NOT NULL
								SET @Handling_Mode = @QUOTAX
							ELSE
								--CUSTOM ADIGE setto handling mode
								SELECT	@Handling_Mode = Handling_Mode
								FROM	Tipo_Udc
								WHERE	Id_Tipo_Udc =	(
															SELECT	Id_Tipo_Udc
															FROM	Udc_Testata
															WHERE	Id_Udc = @Id_udc
														)

							--Quando creo i messaggi devo specificare l'Handling Mode in base al tipo UDC 	
							EXEC @Return = sp_CreaMsg_LuMovetoAsi
											@Handling_Mode = @Handling_Mode
											,@Xml_Param = @Xml_Param
											,@Id_Processo = @Id_Processo
											,@Origine_Log = @Origine_Log
											,@Id_Utente = @Id_Utente
											,@Errore = @Errore OUTPUT
						END
						ELSE IF @Id_Tipo_Messaggio = '1219'
						BEGIN
							EXEC @Return = sp_CreaMsg_MoveItem
									@Id_Missione					= @Id_Missione,
									@Sequenza_Percorso				= @Sequenza_Percorso,
									@Id_Componente_Macchina			= @Id_Componente_Macchina,
									@Id_Partizione_Destinazione		= @Id_Partizione_Destinazione,
									@Id_Processo					= @Id_Processo,
									@Origine_Log					= @Origine_Log,
									@Id_Utente						= @Id_Utente,
									@Errore							= @Errore OUTPUT

							IF @Return <> 0 RAISERROR(@Errore,12,1)
						END
					END
				END
			END

			SET @Flag_Esecuzione_Passo = NULL
			SET @Id_Partizione_Deposito = NULL
			SET @Id_SottoAreaDeposito = NULL
			SET @Id_Partizione_Macchina = NULL;

			COMMIT TRANSACTION
				
			FETCH NEXT FROM @Cursore INTO
			@Id_Raggruppa_Udc
			,@Id_Missione
			,@Id_Tipo_Missione
			,@Id_Udc	
			,@Id_Stato_Missione
			,@Id_Partizione_Sorgente
			,@Id_Componente_Sorgente
			,@ID_SOTTOCOMPONENTE_SORG
			,@Id_Tipo_Cella_Sorgente
			,@Capienza_Cella_Sorgente
			,@Id_Partizione_Destinazione
			,@Id_Componente_Destinazione
			,@Id_Tipo_Cella_Destinazione
			,@Capienza_Cella_Destinazione		
			,@Id_Gruppo_Lista
			,@Id_Stato_Gruppo
			,@Handling_Mode
			,@Handling_Mode_udc
			,@Sequenza_Percorso
			,@Stored_Procedure
			,@Xml_Param
			,@Id_Tipo_Messaggio
			,@ID_TIPO_UDC
			,@ID_SOTTOAREA_SORG 
			,@QuotaDeposito 
			,@Direzione 
			,@PROFONDITA_UDC
			,@PROFONDITA_CELLA
			,@Id_Partizione_Deposito
			,@CapacitaDeposito
			,@Quota
			,@QUOTAX
			,@cod_abb_sorg
			,@DEST_FINALE
			--,@FLAG_SPECIALE
		END

		CLOSE @Cursore
		DEALLOCATE @Cursore;
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		--IF @TranCount = 0 COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @@TRANCOUNT <> 0 
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
	END CATCH
END



GO
