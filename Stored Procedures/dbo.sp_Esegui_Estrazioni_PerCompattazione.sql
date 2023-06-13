SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Esegui_Estrazioni_PerCompattazione]
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
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @Id_Sottoarea				INT
		
		DECLARE @Posizioni_Buffer			INT
		DECLARE @Id_Udc_Da_Compattare		INT
		DECLARE @Id_Missione				INT

		DECLARE @Articoli_In_Baia			TABLE (Id_Udc INT, Id_Articolo INT)
		
		DECLARE Cursore CURSOR LOCAL FAST_FORWARD FOR
			SELECT	P.ID_PARTIZIONE,
					C.ID_SOTTOAREA
			FROM	dbo.Parametri_Generali	PG
			JOIN	dbo.Partizioni			P
			ON		CONCAT('Compattazione_Avviata_',SUBSTRING(P.DESCRIZIONE,1,4)) = PG.Id_Parametro
			JOIN	dbo.SottoComponenti		SC
			ON		P.ID_SOTTOCOMPONENTE = SC.ID_SOTTOCOMPONENTE
			JOIN	dbo.Componenti			C
			ON		SC.ID_COMPONENTE = C.ID_COMPONENTE
			WHERE	PG.Valore = 'true'

		OPEN Cursore
		FETCH NEXT FROM Cursore INTO
			@Id_Partizione_Destinazione,
			@Id_Sottoarea

		WHILE @@FETCH_STATUS = 0
		BEGIN
			DELETE @Articoli_In_Baia

			SET @Posizioni_Buffer = 0
			SET @Id_Udc_Da_Compattare = NULL

			SELECT	@Posizioni_Buffer = COUNT(P.ID_PARTIZIONE)
			FROM	dbo.Partizioni			P
			JOIN	dbo.SottoComponenti		SC
			ON		P.ID_SOTTOCOMPONENTE = SC.ID_SOTTOCOMPONENTE
			JOIN	dbo.Componenti			C
			ON		SC.ID_COMPONENTE = C.ID_COMPONENTE
				AND C.ID_SOTTOAREA = @Id_Sottoarea
				AND P.ID_PARTIZIONE <= @Id_Partizione_Destinazione
			
			SELECT	@Posizioni_Buffer = @Posizioni_Buffer - COUNT(1)
			FROM	dbo.Missioni
			WHERE	Id_Partizione_Destinazione = @Id_Partizione_Destinazione

			SELECT	@Posizioni_Buffer = @Posizioni_Buffer - COUNT(1)
			FROM	dbo.Udc_Posizione		UP
			JOIN	Partizioni				P
			ON		P.ID_PARTIZIONE = UP.Id_Partizione
			JOIN	SottoComponenti			SC
			ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
			JOIN	Componenti				C
			ON		C.ID_COMPONENTE = SC.ID_COMPONENTE
			LEFT
			JOIN	Missioni				M
			ON		M.Id_Udc = UP.Id_Udc
			WHERE	C.ID_SOTTOAREA = @Id_Sottoarea
				AND M.Id_Missione IS NULL

			IF @Posizioni_Buffer > 0
			BEGIN
				--SE HO GIA QUALCOSA IN MISSIONE O SULLA BAIA DEVO ESTRARRE PRIMA PER PARITA DI ARTICOLO ALTRIMENTI PRENDO A CASO UN UDC CHE E' DA COMPATTARE
				INSERT INTO @Articoli_In_Baia
					(Id_Udc,Id_Articolo)
				SELECT	UD.Id_Udc,
						UD.Id_Articolo
				FROM	dbo.Udc_Dettaglio	UD
				JOIN	dbo.Udc_Posizione	UP
				ON		UP.Id_Udc = UD.Id_Udc
					AND UP.Id_Partizione = @Id_Partizione_Destinazione
				UNION
				SELECT	UD.Id_Udc,
						UD.Id_Articolo
				FROM	dbo.Udc_Dettaglio	UD
				JOIN	dbo.Missioni		M
				ON		M.Id_Udc = UD.Id_Udc
					AND M.Id_Tipo_Missione = 'COM'
					AND M.Id_Partizione_Destinazione = @Id_Partizione_Destinazione

				SELECT	@Id_Udc_Da_Compattare = UT.Id_Udc
				FROM	dbo.Udc_Testata			UT
				JOIN	dbo.Udc_Posizione		UP
				ON		UP.Id_Udc = UT.Id_Udc
					AND ISNULL(UT.Da_Compattare,0) = 1
					AND UT.ID_TIPO_UDC NOT IN ('4','5','6')
				JOIN	dbo.Partizioni			P
				ON		P.ID_PARTIZIONE = UP.Id_Partizione
					AND P.ID_TIPO_PARTIZIONE = 'MA'
				JOIN	dbo.Udc_Dettaglio		UD
				ON		UD.Id_Udc = UT.Id_Udc
				LEFT
				JOIN	@Articoli_In_Baia		AB
				ON		AB.Id_Articolo = UD.Id_Articolo
				ORDER
					BY	ISNULL(AB.Id_Articolo,0)	DESC,
						P.CODICE_ABBREVIATO			DESC,
						UT.Data_Inserimento,
						UD.Quantita_Pezzi			DESC

				IF @Id_Udc_Da_Compattare IS NOT NULL
				BEGIN
					EXEC dbo.sp_Insert_CreaMissioni
						@Id_Udc						= @Id_Udc_Da_Compattare,
						@Id_Partizione_Destinazione = @Id_Partizione_Destinazione,
					    @Id_Tipo_Missione			= 'COM',
					    @Id_Missione				= @Id_Missione	OUTPUT,
						@Id_Processo				= @Id_Processo,
					    @Origine_Log				= @Origine_Log,
					    @Id_Utente					= @Id_Utente,
					    @Errore						= @Errore		OUTPUT

					IF @Id_Missione > 0
						BREAK;
				END
			END

			FETCH NEXT FROM Cursore INTO
				@Id_Partizione_Destinazione,
				@Id_Sottoarea
		END

		CLOSE Cursore
		DEALLOCATE Cursore
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
