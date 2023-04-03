SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Rimuovi_Flag_Qualita_NoSap]
	@Id_UdcDettaglio			INT,
	@CONTROL_LOT				VARCHAR(40)	= NULL,
	@Quantita_Libera			NUMERIC(18,4),
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
		-- Dichiarazioni Variabili;
		DECLARE @Id_Udc						INT
		DECLARE @Id_Partizione_Destinazione INT
		DECLARE @Id_Articolo				INT
		DECLARE @Quantita_Pezzi				NUMERIC(18,4)
		DECLARE @Wbs_Riferimento			VARCHAR(MAX)
		
		SELECT	@Id_Articolo				= UD.Id_Articolo,
				@Id_Partizione_Destinazione = UP.ID_Partizione,
				@Quantita_Pezzi				= UD.Quantita_Pezzi,
				@Wbs_Riferimento			= UD.WBS_Riferimento,
				@Id_Udc						= UD.Id_Udc
		FROM	Udc_Dettaglio		UD
		JOIN	Udc_Posizione		UP
		ON		UD.Id_Udc = UP.Id_Udc
		WHERE	UD.Id_UdcDettaglio = @Id_UdcDettaglio

		IF @Id_Udc = 702
			THROW 50001, 'OPERAZIONE NON ESEGUIBILE SU MODULA DA AWM', 1

		IF @Quantita_Libera > @Quantita_Pezzi
			THROW 50001, 'LA SOMMA TRA LA QUANTITA NON CONFORME E LA QUANTITA CONFORME DEVONO CORRISPONDERE ALLA QUANTITA DA CONTROLLARE', 1
			
		IF EXISTS (SELECT TOP(1) 1 FROM Custom.ControlloQualita WHERE Id_UdcDettaglio = @Id_UdcDettaglio AND ISNULL(Doppio_Step_QM,0) = 0 AND ISNULL(CONTROL_LOT,'') = ISNULL(@CONTROL_LOT,''))
			THROW 50009,'OPERAZIONE NON VALIDA PER CASI A SINGOLO STEP QM',1

		--Elimino dalla tabella controllo
		UPDATE	Custom.ControlloQualita
		SET		Quantita = Quantita - @Quantita_Libera
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
			AND ISNULL(@CONTROL_LOT,'') = ISNULL(CONTROL_LOT,'')

		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Custom.ControlloQualita
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
								AND ISNULL(@CONTROL_LOT,'') = ISNULL(CONTROL_LOT,'')
								AND Quantita > 0
						)
			DELETE	Custom.ControlloQualita
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
				AND ISNULL(@CONTROL_LOT,'') = ISNULL(CONTROL_LOT,'')
		
		IF @Quantita_Libera > 0
		BEGIN
			--VERIFICO SE ESITONO MANCANTI LEGATI A QUESTO DETTAGLIO E NEL CASO LANCIO L'EVENTO MANCANTE. VERIFICO ANCHE LA WBS ANCHE SE DOVREBBE ESSERE GIUSTA.
			IF EXISTS	(
							SELECT	TOP(1) 1
							FROM	Custom.AnagraficaMancanti	AM
							JOIN	Udc_Dettaglio				UD
							ON		AM.Id_Articolo = UD.Id_Articolo
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
								AND AM.Qta_Mancante > 0
								AND ISNULL(AM.WBS_Riferimento,'') = ISNULL(@Wbs_Riferimento,'')
						)
					AND
				EXISTS	(
							SELECT	TOP(1) 1
							FROM	Udc_Dettaglio	UD
							JOIN	Udc_Testata		UT
							ON		UD.Id_Udc = UT.Id_Udc
							JOIN	Udc_Posizione	UP
							ON		UP.Id_Udc = UT.Id_Udc
							JOIN	Baie			B
							ON		UP.Id_Partizione = B.Id_Partizione
							WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
						)
			BEGIN
				--lancio l'evento di picking MANCANTE
				DECLARE @XmlParam xml = CONCAT('<Parametri><Id_Udc>',@Id_Udc,'</Id_Udc><Id_Articolo>',@Id_Articolo,'</Id_Articolo><Missione_Modula>',0,'</Missione_Modula></Parametri>')
				EXEC @Return = sp_Insert_Eventi
							@Id_Tipo_Evento		= 36,
							@Id_Partizione		= @Id_Partizione_Destinazione,
							@Id_Tipo_Messaggio	= 1100,
							@XmlMessage			= @XmlParam,
							@Id_Processo		= @Id_Processo,
							@Origine_Log		= @Origine_Log,
							@Id_Utente			= @Id_Utente,
							@Errore				= @Errore OUTPUT

				IF @Return <> 0
					RAISERROR(@Errore,12,1)
			END
		END

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
