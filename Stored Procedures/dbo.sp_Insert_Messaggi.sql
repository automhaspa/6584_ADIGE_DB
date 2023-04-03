SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Insert_Messaggi]
	@Id_Messaggio					INT				= NULL OUTPUT,
	@Id_Tipo_Direzione_Messaggio	VARCHAR(1),
	@XmlMessage						XML,
	@Id_Plc							INT,
	@Id_Tipo_Stato_Messaggio		INT,
	-- Parametri Standard;
	@Id_Processo					VARCHAR(30),
	@Origine_Log					VARCHAR(25),
	@Id_Utente						VARCHAR(16),
	@SavePoint						VARCHAR(32)		= NULL,
	@Errore							VARCHAR(500)			OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	SET LOCK_TIMEOUT 5000

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Bit
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY
		-- Dichiarazioni Variabili;
		DECLARE @Asi				Varchar(4)
		DECLARE @Area				Varchar(1)
		DECLARE @SottoArea			Varchar(1)
		DECLARE @Componente			Varchar(2)
		DECLARE @SottoComponente	Varchar(4)
		DECLARE @Partizione			Varchar(4)
		DECLARE @Id_Tipo_Messaggio	Varchar(5)
		DECLARE @Id_Area			Int
		DECLARE @Id_SottoArea		Int
		DECLARE @Id_Componente		Int
		DECLARE @Id_SottoComponente	Int
		DECLARE @Id_Partizione		Int
		DECLARE @Esistente			Int

		-- Dichiarazione Procedure;
	
		-- Inserimento del codice;
		SET @Errore = ''

		SET @Asi = @XmlMessage.value('data(//Asi)[1]','varchar(4)')
		SET @Area = @XmlMessage.value('fn:substring(data(//Asi)[1],1,1)','varchar(1)')			
		SET @SottoArea = @XmlMessage.value('fn:substring(data(//Asi)[1],2,1)','varchar(1)')	
		SET @Componente = @XmlMessage.value('fn:substring(data(//Asi)[1],3,2)','varchar(2)')	
		SET @SottoComponente = @XmlMessage.value('data(//SubItem)[1]','varchar(4)')
		SET @Partizione	= @XmlMessage.value('data(//Partition)[1]','varchar(4)')
		SET @Id_Tipo_Messaggio = @XmlMessage.value('data(//MsgId)[1]','varchar(5)')	

		SELECT	@Id_Area = AR.ID_AREA,
			    @Id_SottoArea = SA.ID_SOTTOAREA,
			    @Id_Componente = C.ID_COMPONENTE,
			    @Id_SottoComponente = SC.ID_SOTTOCOMPONENTE,
			    @Id_Partizione = P.ID_PARTIZIONE
		FROM	Aree			AR
		LEFT
		JOIN	SOTTOAREE		SA
		ON		SA.ID_AREA = AR.ID_AREA
		LEFT
		JOIN	COMPONENTI		C
		ON		C.ID_SOTTOAREA = SA.ID_SOTTOAREA
		LEFT
		JOIN	SottoComponenti SC
		ON		SC.Id_Componente = C.Id_Componente
		LEFT
		JOIN	Partizioni		P
		ON		P.ID_SOTTOCOMPONENTE = SC.ID_SOTTOCOMPONENTE
		WHERE	AR.CODICE_ABBREVIATO = @AREA
			AND SA.CODICE_ABBREVIATO = @SottoArea
			AND C.Codice_Abbreviato = @COMPONENTE
			AND (@SOTTOCOMPONENTE = '0000' OR SC.CODICE_ABBREVIATO = @SOTTOCOMPONENTE)
			AND (@PARTIZIONE = '0000' OR P.CODICE_ABBREVIATO = @Partizione)

		IF @Id_Tipo_Direzione_Messaggio = 'R'
		BEGIN
			INSERT INTO Messaggi_Ricevuti (Id_Tipo_Messaggio,Id_Area,Id_SottoArea,Id_Componente,Id_SottoComponente,Id_Partizione,Messaggio,Id_Tipo_Stato_Messaggio)
			VALUES (@Id_Tipo_Messaggio,@Id_Area,@Id_SottoArea,@Id_Componente,@Id_SottoComponente,@Id_Partizione,@XmlMessage,@Id_Tipo_Stato_Messaggio)

			SELECT @Id_Messaggio = SCOPE_IDENTITY()
		END
		ELSE IF @Id_Tipo_Direzione_Messaggio = 'S'
		BEGIN
			INSERT INTO Messaggi_Inviati (Id_Tipo_Messaggio,Id_Area,Id_SottoArea,Id_Componente,Id_SottoComponente,Id_Partizione,Messaggio,Id_Tipo_Stato_Messaggio,Id_Plc)
			VALUES (@Id_Tipo_Messaggio,@Id_Area,@Id_SottoArea,@Id_Componente,@Id_SottoComponente,@Id_Partizione,@XmlMessage,@Id_Tipo_Stato_Messaggio,@Id_Plc)

			SELECT @Id_Messaggio = SCOPE_IDENTITY()
		END
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		--SET @Errore = @Id_Tipo_Messaggio + ',' + CONVERT(Varchar,@Id_Gruppo) + ',' + CONVERT(Varchar,@Id_Azienda) + ',' + CONVERT(Varchar,@Id_Stabilimento) + ',' + CONVERT(Varchar,@Id_Magazzino) + ',' + CONVERT(Varchar,@Id_Area) + ',' + CONVERT(Varchar,@Id_SottoArea) + ',' + CONVERT(Varchar,@Id_Componente) + ',' + CONVERT(Varchar,@Id_SottoComponente) + ',' + CONVERT(Varchar,@Id_Partizione)
		--+ ',' + CONVERT(Varchar,@XmlMessage)--@Id_Tipo_Stato_Messaggio,@Id_Plc
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
		BEGIN
			ROLLBACK TRANSACTION
			EXEC sp_Insert_Log @Id_Processo,@Origine_Log,@Nome_StoredProcedure,@Id_Utente,4,0,'',@Errore,@Errore OUTPUT
		END
		-- Return 0 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END


GO
