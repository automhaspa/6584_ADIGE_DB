SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_GestMsg_ItemEvent]
@Id_Messaggio	Int
-- Parametri Standard;
,@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(32)		
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	SET LOCK_TIMEOUT 5000

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
	DECLARE @ErrLog Varchar(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = Object_Name(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Asi Varchar(4)
		DECLARE @SottoComponente Varchar(4) 
		DECLARE @Partizione Varchar(4)
		DECLARE @Id_Partizione Int
		DECLARE @XmlMessage xml
		DECLARE @EventCode Int
		DECLARE	@Event_Param_0 Int	
		DECLARE	@Event_Param_1 Int
		DECLARE	@Event_Param_2 Int
		DECLARE	@Event_Param_3 Int
		DECLARE	@Event_Param_4 Int
		DECLARE	@Event_Param_5 Int
		DECLARE	@Event_Param_6 Int
		DECLARE	@Event_Param_7 Int
		DECLARE	@Event_Param_8 Int
		DECLARE	@Event_Param_9 Int
		DECLARE @Id_Udc Int
		DECLARE @Xml Xml
		DECLARE @WkTable TABLE (Posizione Varchar(2),Lettura Varchar(50))
		DECLARE @Cursore CURSOR
		DECLARE @Codice_Udc Varchar(50)
		DECLARE @Id_Partizione_Destinazione int
		DECLARE @Id_Tipo_Missione Varchar(3)
		DECLARE @Filmatura Int
			
		-- Inserimento del codice;
		SELECT @xmlMessage = Messaggio FROM Messaggi_Ricevuti WITH(NOLOCK) WHERE Id_Messaggio = @Id_Messaggio

		SET @Asi = @XmlMessage.value('data(//Asi)[1]','Varchar(4)')	
		SET @SottoComponente = @XmlMessage.value('data(//SubItem)[1]','Varchar(4)')	 
		SET @Partizione = @XmlMessage.value('data(//Partition)[1]','Varchar(4)')
		SET @EventCode = @XmlMessage.value('data(//EventCode)[1]','Int')	
		SET @Event_Param_0 = @XmlMessage.value('data(//Event_Param_0)[1]','Int')
		SET @Event_Param_1 = @XmlMessage.value('data(//Event_Param_1)[1]','Int')
		SET @Event_Param_2 = @XmlMessage.value('data(//Event_Param_2)[1]','Int')
		SET @Event_Param_3 = @XmlMessage.value('data(//Event_Param_3)[1]','Int')
		SET @Event_Param_4 = @XmlMessage.value('data(//Event_Param_4)[1]','Int')
		SET @Event_Param_5 = @XmlMessage.value('data(//Event_Param_5)[1]','Int')
		SET @Event_Param_6 = @XmlMessage.value('data(//Event_Param_6)[1]','Int')
		SET @Event_Param_7 = @XmlMessage.value('data(//Event_Param_7)[1]','Int')
		SET @Event_Param_8 = @XmlMessage.value('data(//Event_Param_8)[1]','Int')
		SET @Event_Param_9 = @XmlMessage.value('data(//Event_Param_9)[1]','Int')

		SELECT	@Id_Partizione = Id_Partizione
		FROM	Partizioni WITH(NOLOCK)
				INNER JOIN SottoComponenti WITH(NOLOCK) ON SottoComponenti.Id_SottoComponente = Partizioni.Id_SottoComponente
				INNER JOIN Componenti WITH(NOLOCK) ON Componenti.Id_Componente = SottoComponenti.Id_Componente
				INNER JOIN SottoAree WITH(NOLOCK) ON SottoAree.Id_SottoArea = Componenti.Id_SottoArea
				INNER JOIN Aree WITH(NOLOCK) ON Aree.Id_Area = SottoAree.Id_Area
		WHERE	Aree.Codice_Abbreviato = SUBSTRING(@Asi,1,1) 
				AND SottoAree.Codice_Abbreviato = SUBSTRING(@Asi,2,1)
				AND Componenti.Codice_Abbreviato = SUBSTRING(@Asi,3,2)
				AND SottoComponenti.Codice_Abbreviato = @SottoComponente
				AND Partizioni.Codice_Abbreviato = @Partizione

		SELECT	@Id_Udc = Id_Udc
		FROM	Udc_Posizione WITH(NOLOCK)
		WHERE	Id_Partizione = @Id_Partizione
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 1 se tutto è andato a buon fine;
		RETURN 0
	END TRY
	BEGIN CATCH
		-- Valorizzo l'errore con il nome della procedura corrente seguito dall'errore scatenato nel codice;
		SET @Errore = @Nome_StoredProcedure + ';' + ERROR_MESSAGE()
		-- Eseguo il rollback ed inserisco il log solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 
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
				
				-- Return 0 se la procedura è andata in errore;
				RETURN 1
		END
		ELSE THROW
	END CATCH
END

GO
