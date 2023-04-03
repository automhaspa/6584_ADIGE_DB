SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- Batch submitted through debugger: SQLQuery2.sql|7|0|C:\Users\simone.mazzoleni\AppData\Local\Temp\~vsDCAF.sql

CREATE PROC [dbo].[sp_Output_PropostaUbicazione]	
	@ID_UDC			INT,
	@QUOTADEPOSITOX INT = NULL OUT,	
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
		DECLARE @START DATETIME = GETDATE()

		-- Dichiarazioni Variabili;
		DECLARE @ID_PARTIZIONE_DESTINAZIONE INT
		DECLARE @LARGHEZZA					INT
		DECLARE @PROFONDITA					INT
		DECLARE @ALTEZZA					INT
		DECLARE @ID_PARTIZIONE_SORGENTE		INT
		DECLARE @Colonna_Sorgente			INT
		DECLARE @Piano_Sorgente				INT
		DECLARE @ID_SOTTOCOMPONENTE_SORG	INT
		DECLARE @Id_Tipo_Udc				VARCHAR(1)
		--Setto temporaneamente il Margine = 10
		DECLARE @MARGINE					INT = 10
		DECLARE @PLUS_LARGHEZZA_SX			INT
		DECLARE	@PLUS_LARGHEZZA_DX			INT
		DECLARE @PESO						INT

		--Inserimento del codice
		--Seleziono Larghezza,Profondità,Altezza,Peso Posiziione dell'Udc passata come parametro
		SELECT	@LARGHEZZA					= UT.Larghezza,
				@PROFONDITA					= UT.Profondita,
				@ALTEZZA					= UT.Altezza,
				@Id_Tipo_Udc				= UT.Id_Tipo_Udc,
				@ID_PARTIZIONE_SORGENTE		= UP.Id_Partizione,
				@Colonna_Sorgente			= ISNULL(SC.COLONNA,0),
				@Piano_Sorgente				= ISNULL(SC.PIANO,0),
				@ID_SOTTOCOMPONENTE_SORG	= P.ID_SOTTOCOMPONENTE,
				@PESO						= UT.Peso
		FROM	dbo.Udc_Testata		UT
		JOIN	dbo.Tipo_Udc		TU	ON TU.Id_Tipo_Udc = UT.Id_Tipo_Udc
		JOIN	dbo.Udc_Posizione	UP	ON UP.Id_Udc = UT.Id_Udc
		JOIN	dbo.Partizioni		P	ON P.ID_PARTIZIONE = UP.Id_Partizione
		JOIN	dbo.SottoComponenti SC	ON SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
		WHERE	UT.ID_UDC = @ID_UDC
		
		--Assegno a fn_Tempo il risultato delle subqueries
		;WITH fn_Tempo AS
		(				
			SELECT	fnT.Id_Partizione_Baia,
					fnT.Id_Partizione_Magazzino,
					scT.Id_Componente			Id_Componente_Magazzino,
					fnT.Direction,
					fnT.Priorita,
					scT.PIANO,
					scT.COLONNA
			FROM	dbo.fnTempo				fnT
			JOIN	dbo.Partizioni			pT
			ON		fnT.Id_Partizione_Magazzino = pT.ID_PARTIZIONE
			JOIN	dbo.SottoComponenti		scT
			ON		scT.ID_SOTTOCOMPONENTE = pT.ID_SOTTOCOMPONENTE
			WHERE	fnT.Flag_Attivo = 1
			--Recupero il record fnTempo che parte dalla partizione sorgente della sp
				AND	fnT.Id_Partizione_Baia = @ID_PARTIZIONE_SORGENTE
			UNION
			--X missioni di scambio tra partizioni di tipo MA
			SELECT	P.ID_PARTIZIONE			Id_Partizione_Baia,
					P.ID_PARTIZIONE			Id_Partizione_Magazzino,
					SC.ID_COMPONENTE		Id_Componente_Magazzino,
					'A'						Direction,
					1,
					SC.PIANO,
					SC.COLONNA
			FROM	dbo.Partizioni		P
			JOIN	dbo.SottoComponenti SC
			ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE				
			WHERE	P.ID_PARTIZIONE = @ID_PARTIZIONE_SORGENTE
				AND	P.ID_TIPO_PARTIZIONE = 'MA'							
		),
		MISSIONI_ATTIVE AS
		(
			--Seleziono Missioni Attive
			SELECT	SC_ATT.ID_COMPONENTE,
					COUNT(0) #COUNT
			FROM	dbo.Missioni		M_ATT
			JOIN	dbo.Partizioni		P_ATT
			ON		P_ATT.ID_PARTIZIONE = M_ATT.Id_Partizione_Destinazione
			JOIN	dbo.SottoComponenti SC_ATT
			ON		SC_ATT.ID_SOTTOCOMPONENTE = P_ATT.ID_SOTTOCOMPONENTE
			GROUP
				BY	SC_ATT.ID_COMPONENTE
		),
		DISTRIBUZIONE AS
		(
			--CONTO il numero di Udc presenti in una determinata area 
			SELECT	ID_COMPONENTE,
					COUNT(0) #UDC
			FROM	dbo.Udc_Posizione		UP
			JOIN	AwmConfig.vPartizioni	vP
			ON		vP.ID_PARTIZIONE = UP.Id_Partizione
			GROUP
				BY	ID_COMPONENTE
		)
		SELECT	@ID_PARTIZIONE_DESTINAZIONE = P.ID_PARTIZIONE,
				@QUOTADEPOSITOX =	CASE
										WHEN allocazione_0002.POS IS NOT NULL THEN allocazione_0002.POS
										ELSE freeSpace.PosX + @MARGINE
									END
		FROM	dbo.vSpazioDisponibile		freeSpace
		LEFT
		JOIN	(
					SELECT	vPV.ID_SOTTOCOMPONENTE,
							UT.Larghezza,
							POS,
							POS + UT.Larghezza		POSDX
					FROM	dbo.vPosizioniVertici	vPV
					JOIN	dbo.Udc_Testata			UT
					ON		UT.Id_Udc = vPV.Id_Udc
					JOIN	dbo.SottoComponenti		SC
					ON		SC.ID_SOTTOCOMPONENTE = vPV.ID_SOTTOCOMPONENTE
					WHERE	UDCDX = 0
						AND vPV.Id_Udc IS NOT NULL
						AND vPV.CODICE_ABBREVIATO = '0002'
						AND vPV.Larghezza = @LARGHEZZA
				)	allocazione_0002 
		ON		allocazione_0002.ID_SOTTOCOMPONENTE = freeSpace.ID_SOTTOCOMPONENTE
			AND freeSpace.CODICE_ABBREVIATO   = '0001'
			AND freeSpace.PosX <= allocazione_0002.POS 
			AND freeSpace.PosX + freeSpace.SpazioDisponibile >= POSDX
		JOIN	dbo.Partizioni			P
		ON		P.ID_PARTIZIONE = freeSpace.ID_PARTIZIONE
		JOIN	dbo.SottoComponenti		SC
		ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
		JOIN	fn_Tempo
		ON		fn_Tempo.Id_Componente_Magazzino = SC.ID_COMPONENTE
		LEFT
		JOIN	MISSIONI_ATTIVE		MA
		ON		MA.ID_COMPONENTE = SC.ID_COMPONENTE
		LEFT
		JOIN	DISTRIBUZIONE		D
		ON		D.ID_COMPONENTE = SC.ID_COMPONENTE
		WHERE	P.ID_SOTTOCOMPONENTE <> @ID_SOTTOCOMPONENTE_SORG
			AND ISNULL(P.LOCKED,0) = 0
			AND	NOT EXISTS	(
								SELECT	TOP 1 1
								FROM	dbo.Percorso		PERC_2
								JOIN	dbo.Partizioni		P_2
								ON		P_2.ID_PARTIZIONE IN (PERC_2.Id_Partizione_Destinazione, PERC_2.Id_Partizione_Sorgente)
									AND P_2.ID_TIPO_PARTIZIONE = 'MA'
									AND PERC_2.Id_Tipo_Stato_Percorso <> 3
									AND P_2.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
							)
			AND freeSpace.SpazioDisponibile >= @LARGHEZZA + @MARGINE -- + @PLUS_LARGHEZZA_SX + @PLUS_LARGHEZZA_DX
			AND P.PESO >= @PESO
			AND freeSpace.PROF_SLOT >= @PROFONDITA 
			AND P.ALTEZZA >= @ALTEZZA
			AND P.CAPIENZA > (SELECT COUNT(0) FROM dbo.Udc_Posizione WHERE Id_Partizione = freeSpace.ID_PARTIZIONE)
			AND (freeSpace.CODICE_ABBREVIATO = '0002' OR allocazione_0002.POS IS NOT NULL OR SC.ID_COMPONENTE = 1201 OR SC.ID_COMPONENTE = 1102)
			AND (NOT(SC.COLONNA = 1 AND @Id_Tipo_Udc IN ('1', '2', '3')))						
		ORDER
			BY	ISNULL(MA.#COUNT,0)				DESC,
				P.ALTEZZA						DESC,
				freeSpace.PROF_SLOT				DESC,
				ISNULL(D.#UDC,0)				DESC,
				--,COUNT(UP.Id_Partizione) OVER (PARTITION BY SC.ID_COMPONENTE) * 100 / COUNT(P.ID_PARTIZIONE) OVER (PARTITION BY SC.ID_COMPONENTE) DESC
				CASE
					WHEN SC.ID_COMPONENTE = 1201 or SC.ID_COMPONENTE = 1102  THEN '0002' 
					ELSE P.CODICE_ABBREVIATO
				END								ASC,
				--,COUNT(UP.Id_Partizione) OVER (PARTITION BY SC.ID_COMPONENTE) * 100 / COUNT(P.ID_PARTIZIONE) OVER (PARTITION BY SC.ID_COMPONENTE) DESC
				P.CODICE_ABBREVIATO				ASC,
				SQRT(POWER(ABS(ISNULL(@Colonna_Sorgente,fn_Tempo.COLONNA) - SC.COLONNA), 2)
					+ POWER(ABS(ISNULL(@Piano_Sorgente,fn_Tempo.PIANO) - SC.PIANO), 2)) DESC,
				P.ID_SOTTOCOMPONENTE			DESC,
				ISNULL(allocazione_0002.Larghezza,freeSpace.SpazioDisponibile)			DESC
		-- Fine del codice;

		IF @ID_PARTIZIONE_DESTINAZIONE IS NULL
			THROW 50001,'NESSUNA DESTINAZIONE TROVATA',1
		
		DECLARE @TEMPO INT = DATEDIFF(MILLISECOND,@START,GETDATE())
		
		IF @TEMPO > 500
		BEGIN
			DECLARE @MSG_LOG VARCHAR(MAX) = CONCAT('Prop. Ubicazione UDC ',@ID_UDC,' destinazione ', @ID_PARTIZIONE_DESTINAZIONE,' - TEMPO IMPIEGATO ',@TEMPO)
			EXEC dbo.sp_Insert_Log
					@Id_Processo		= @Id_Processo,
					@Origine_Log		= @Origine_Log,
					@Proprieta_Log		= 'Tempistiche',
					@Id_Utente			= @Id_Utente,
					@Id_Tipo_Log		= 16,
					@Id_Tipo_Allerta	= 0,
					@Messaggio			= @MSG_LOG,
					@Errore				= @Errore OUTPUT;
		END

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION;
		-- Return 0 se tutto è andato a buon fine;
		RETURN @ID_PARTIZIONE_DESTINAZIONE
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
			END
		ELSE THROW
	END CATCH
END


GO
