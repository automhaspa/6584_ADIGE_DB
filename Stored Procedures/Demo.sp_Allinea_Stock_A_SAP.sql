SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE PROCEDURE [Demo].[sp_Allinea_Stock_A_SAP]
	@CODICE_ARTICOLO	VARCHAR(MAX),
	@Qta_SAP			INT,
	@WBS_Riferimento	VARCHAR(24) = '',
	-- Parametri Standard;
	@Id_Processo		VARCHAR(30),
	@Origine_Log		VARCHAR(25),
	@Id_Utente			VARCHAR(16),
	@Errore				VARCHAR(500) OUTPUT
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
		DECLARE @Id_Articolo	INT 
		DECLARE @Qta_Stock		INT

		SELECT	@Id_Articolo = Id_Articolo
		FROM	Articoli
		WHERE	Codice = @CODICE_ARTICOLO

		IF @Id_Articolo IS NULL
			THROW 50009, 'ARTICOLO NON TROVATO',1

		SELECT	@Qta_Stock = SUM(quantita_Pezzi)
		FROM	Udc_Dettaglio 
		WHERE	Id_Articolo = @id_articolo
			AND ISNULL(WBS_RIFERIMENTO,'') = ISNULL(@WBS_Riferimento,'')

		select  @Qta_Stock
		IF ISNULL(@Qta_Stock,0) < @Qta_SAP
		BEGIN
			DECLARE @Id_UdcDettaglio_DaModificare INT
			
			SELECT	@Id_UdcDettaglio_DaModificare = Id_UdcDettaglio
			FROM	Udc_Dettaglio		UD
			JOIN	Udc_Posizione		UP
			ON		UP.Id_Udc = UD.Id_Udc
				AND UP.Id_Udc <> 702
			JOIN	Partizioni			P
			ON		P.ID_PARTIZIONE = UP.Id_Partizione
				AND P.ID_TIPO_PARTIZIONE NOT IN ('AT', 'KT', 'AP', 'US', 'OO')
			WHERE	Id_Articolo <> @id_articolo
				AND UD.Quantita_Pezzi > 0
				AND ISNULL(UD.WBS_Riferimento,'') = ''
			
			IF @Id_UdcDettaglio_DaModificare IS NULL
				THROW 50009, 'NON TROVO NESSUN DETTAGLIO DISPONIBILE ALLA MODIFICA',1

			UPDATE	Udc_Dettaglio
			SET		Id_Articolo = @Id_Articolo,
					Quantita_Pezzi = @Qta_SAP
			WHERE	id_udcdettaglio = @Id_UdcDettaglio_DaModificare
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
