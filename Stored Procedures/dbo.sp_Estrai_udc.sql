SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Estrai_udc]
	@Id_Evento					INT,
	@Id_Udc						INT,
	@Specializzazione_Completa	BIT,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(32),	
	@Errore						VARCHAR(500) OUTPUT
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
		DECLARE	@Id_Partizione_Udc	INT

		SELECT	@Id_Partizione_Udc = Id_Partizione
		FROM	Udc_Posizione
		WHERE	Id_Udc = @Id_Udc

		IF @Id_Partizione_Udc NOT IN (3301, 3302, 3501)
			THROW 50001, 'ESTRAZIONE UDC ESEGUIBILE ESCLUSIVAMENTE DA BAIE DI SPECIALIZZAZIONE',1

		--SE STO PER COMPLETARE LA SPECIALIZZAZIONE DELL' UDC
		IF @Specializzazione_Completa = 1
		BEGIN
			--Ma sono l'ultima udc da specializzare
			IF EXISTS	(
							SELECT	TOP 1 1
							FROM	Udc_Testata		UT
							JOIN	Udc_Testata		UT_1
							ON		UT.Id_Ddt_Fittizio = UT_1.Id_Ddt_Fittizio
								AND UT_1.Id_Udc = @Id_Udc
							WHERE	ISNULL(UT.Specializzazione_Completa, 0) = 0
							GROUP
								BY	UT.Id_Ddt_Fittizio
							HAVING	COUNT(1) = 1
						)
			BEGIN
				--CONTROLLO CHE NON RIMANGANO ARTICOLI DA SPECIALIZZARE NEI DDT REALI
				IF EXISTS	(
								SELECT	TOP 1 1
								FROM	AwmConfig.VQtaRimanentiRigheDdt		vQR
								JOIN	Udc_Testata							UT
								ON		UT.Id_Ddt_Fittizio = vQR.Id_Ddt_Fittizio
									AND UT.Id_Udc = @Id_Udc
								WHERE	vQR.QUANTITA_RIMANENTE_DA_SPECIALIZZARE > 0
							)
					THROW 50003,' ATTENZIONE STAI CHIUDENDO L''ORDINE DI SPECIALIZZAZIONE CON QUEST'' ULTIMA UDC MA RIMANGONO DEGLI ARTICOLI
									DA SPECIALIZZARE NEI DDT REALI ASSOCIATI (NEL CASO NON SIANO PRESENTI FORZARE CHIUSURA RIGA)',1
			END
		END

		UPDATE	Udc_Testata
		SET		Specializzazione_Completa = @Specializzazione_Completa
		WHERE	Id_Udc = @Id_Udc

		DELETE	Eventi
		WHERE	Id_Evento = @Id_Evento

		EXEC dbo.sp_Insert_CreaMissioni
					@Id_Udc							= @Id_Udc,
					@Id_Partizione_Destinazione		= 3203,
					@Id_Tipo_Missione				= 'OUT',
					@Xml_Param						= '',
					@Id_Processo					= @Id_Processo,
					@Origine_Log					= @Origine_Log,
					@Id_Utente						= @Id_Utente,
					@Errore							= @Errore			OUTPUT

		IF ISNULL(@Errore, '') <> ''
			THROW 50002, @Errore, 1

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
