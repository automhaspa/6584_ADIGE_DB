SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [dbo].[sp_Assegna_NonConformita]
	@Id_Articolo			INT,
	@MotivoNonConformita	VARCHAR(MAX)	= NULL,
	@Id_Udc					INT				= NULL,
	@Qta_Pezzi				NUMERIC(10,2)	= NULL,
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
		DECLARE @Id_UdcDettaglio	INT
		DECLARE @WBS_CODE			VARCHAR(24)

		IF NOT EXISTS	(
							SELECT	TOP 1 1
							FROM	Udc_Dettaglio
							WHERE	Id_Articolo = @Id_Articolo
						)
			THROW 50001, 'DETTAGLIO NON TROVATO', 1

		SELECT	@Id_UdcDettaglio = UD.Id_UdcDettaglio,
				@Qta_Pezzi = ISNULL(@Qta_Pezzi,UD.Quantita_Pezzi),
				@WBS_CODE = UD.WBS_Riferimento
		FROM	Udc_Dettaglio			UD
		JOIN	Udc_Posizione			UP
		ON		UP.Id_Udc = UD.Id_Udc
		JOIN	Partizioni				P
		ON		P.ID_PARTIZIONE = UP.Id_Partizione
			AND P.ID_TIPO_PARTIZIONE = 'MA'
		LEFT
		JOIN	Custom.ControlloQualita CQ
		ON		UD.Id_UdcDettaglio = CQ.Id_UdcDettaglio
		WHERE	Id_Articolo = @Id_Articolo
			AND UD.Id_Udc = @Id_Udc
			AND CQ.Id_UdcDettaglio IS NULL
			
		IF @Id_UdcDettaglio IS NULL
			THROW 50009, 'DETTAGLIO NON TROVATO VERIFICARE CHE NON SIA GIA'' SOTTOPOSTO A CONTROLLO QUALITA''',1

		DECLARE @Qta_NonConforme INT
		SELECT	@Qta_NonConforme = Quantita
		FROM	Custom.NonConformita
		WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		
		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	Custom.ControlloQualita
						WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
					)
			THROW 50009, 'Dettaglio presente IN CONTROLLO QUALITA. Impossibile spostare in NON CONFORMITA''',1

		IF @Qta_NonConforme IS NULL
			INSERT INTO Custom.NonConformita
				(Id_UdcDettaglio, Quantita, MotivoNonConformita,CONTROL_LOT)
			VALUES
				(@Id_UdcDettaglio, @Qta_Pezzi, @MotivoNonConformita,'')
		ELSE IF @Qta_NonConforme < @Qta_Pezzi
			UPDATE	Custom.NonConformita
			SET		Quantita = @Qta_Pezzi
			WHERE	Id_UdcDettaglio = @Id_UdcDettaglio
		ELSE
			THROW 50009, 'Dettaglio già presente nel dettaglio NON CONFORMI.',1
		
		EXEC [dbo].[sp_Genera_Consuntivo_MovimentiMan]
						@IdCausaleL3			= 'RBL',
						@IdUdcDettaglio			= @Id_UdcDettaglio,
						@IdCausaleMovimento		= 3,
						@Flag_ControlloQualita	= 1,
						@Quantity				= @Qta_Pezzi,
						@WBS_CODE				= @WBS_CODE,
						@Id_Processo			= @Id_Processo,
						@Origine_Log			= @Origine_Log,
						@Id_Utente				= @Id_Utente,
						@Errore					= @Errore					OUTPUT

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
