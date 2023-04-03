SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_WBS_Esecuzione_Prelievo]
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
		-- Dichiarazioni Variabili;
		DECLARE @Id_Tipo_Missione					VARCHAR(3)		= 'WBS'
		
		DECLARE @Id_CambioWBS_C						INT
		DECLARE @Id_Udc_C							INT
		DECLARE @Id_UdcDettaglio_C					INT
		DECLARE @Id_Partizione_Destinazione_C		INT
		DECLARE @WBS_Riferimento_C					VARCHAR(24)
		
		DECLARE @Id_Missione						INT
		DECLARE @Errore_Crea_Missione				VARCHAR(MAX)
		
		--Eseguo le missioni 
		DECLARE CursorTasks CURSOR LOCAL STATIC FOR
			SELECT	UD.Id_Udc,
					UD.Id_UdcDettaglio,
					MWBS.Id_Cambio_WBS,
					UD.WBS_Riferimento,
					MWBS.Id_Partizione_Destinazione
			FROM	Custom.Missioni_Cambio_WBS	MWBS
			JOIN	Custom.CambioCommessaWBS	CWBS
			ON		CWBS.ID = MWBS.Id_Cambio_WBS
			JOIN	Udc_Dettaglio				UD
			ON		ISNULL(UD.WBS_Riferimento,'') = ISNULL(CWBS.WBS_Partenza,'')
				AND CWBS.Id_Stato_Lista = 5
				AND MWBS.ID_STATO_LISTA = 1
				AND MWBS.Id_UdcDettaglio = UD.Id_UdcDettaglio
			JOIN	Udc_Posizione				UP
			ON		UP.Id_Udc = UD.Id_Udc
			JOIN	Udc_Testata					UT
			ON		UT.Id_Udc = UP.Id_Udc
			JOIN	Partizioni					P
			ON		UP.Id_Partizione = P.ID_PARTIZIONE
				AND P.ID_TIPO_PARTIZIONE = 'MA'
				AND ISNULL(P.LOCKED,0) = 0
			LEFT
			JOIN	Missioni					M
			ON		M.Id_Udc = UD.Id_Udc
			WHERE	M.ID_MISSIONE IS NULL
			GROUP
				BY	UD.Id_Udc,
					UD.Id_UdcDettaglio,
					MWBS.Id_Cambio_WBS,
					UD.WBS_Riferimento,
					MWBS.Id_Partizione_Destinazione,
					UP.QuotaDeposito
			ORDER
				BY	UP.QuotaDeposito

		OPEN CursorTasks
		FETCH NEXT FROM CursorTasks INTO
			@Id_Udc_C,
			@Id_UdcDettaglio_C,
			@Id_CambioWBS_C,
			@WBS_Riferimento_C,
			@Id_Partizione_Destinazione_C

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Id_Missione			= NULL
			SET @Errore_Crea_Missione	= NULL

			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.vBufferSpecializzazione
							WHERE	PostiLiberiBuffer > 0
								AND Id_Partizione = @Id_Partizione_Destinazione_C
						)
			BEGIN
				BEGIN TRY
					EXEC dbo.sp_Insert_CreaMissioni
								@Id_Udc						= @Id_Udc_C,
								@Id_Partizione_Destinazione = @Id_Partizione_Destinazione_C,
								@Id_Tipo_Missione			= @Id_Tipo_Missione,
								@Id_Missione				= @Id_Missione			OUTPUT,
								@Xml_Param					= '',
								@Id_Processo				= @Id_Processo,
								@Origine_Log				= @Origine_Log,
								@Id_Utente					= @Id_Utente,
								@Errore						= @Errore				OUTPUT

					IF ISNULL(@Errore,'')<>''
						THROW 50009, @ERRORE, 1

					UPDATE	Custom.Missioni_Cambio_WBS
					SET		Id_Missione = @Id_Missione,
							Id_Stato_Lista = 5,
							DataOra_Esecuzione = GETDATE(),
							DataOra_UltimaModifica = GETDATE()
					WHERE	Id_UdcDettaglio = @Id_UdcDettaglio_C
						AND Id_Cambio_WBS = @Id_CambioWBS_C
				END TRY
				BEGIN CATCH
					SET @Errore_Crea_Missione = CONCAT('ERRORE CREAZIONE MISSIONE UDC TIPO A: ', @Errore, ' Id_Udc : ' , @Id_Udc_C, ' Verso:', @Id_Partizione_Destinazione_C, ' - ', ERROR_MEssage())
					
					EXEC sp_Insert_Log
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Proprieta_Log		= @Nome_StoredProcedure,
							@Id_Utente			= @Id_Utente,
							@Id_Tipo_Log		= 4,
							@Id_Tipo_Allerta	= 0,
							@Messaggio			= @Errore_Crea_Missione,
							@Errore				= @Errore				OUTPUT
				END CATCH
			END

			FETCH NEXT FROM CursorTasks INTO
				@Id_Udc_C,
				@Id_UdcDettaglio_C,
				@Id_CambioWBS_C,
				@WBS_Riferimento_C,
				@Id_Partizione_Destinazione_C

		END

		CLOSE CursorTasks
		DEALLOCATE CursorTasks

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
