SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [dbo].[sp_CreaMsg_LuDataRqToAsi]
@Xml_Param	Xml
,@Id_Missione Int = NULL
,@Sequenza_Percorso Int = NULL
,@Id_Udc Int = NULL
-- Parametri Standard;
,@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(32)		
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure Varchar(30)
	DECLARE @TranCount Int
	DECLARE @Return Int
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
		DECLARE	@MsgId	Int
		DECLARE @Id_Partizione Int
		DECLARE @Id_Plc Int
		DECLARE @XmlMessage xml
		DECLARE @Id_Messaggio Int
		
		-- Inserimento del codice;
		SET @MsgId =	12031
		
		SELECT	@Id_Partizione = Parametri.Colonna.value('@Id_Partizione','Int')
		FROM	@Xml_Param.nodes('/Parametri') Parametri(Colonna)
				
		-- Recupero ASI, SOTTOCOMPONENTE, PARTIZIONE ed Id_Plc partendo dalla partizione passata come parametro.
		SELECT	@Asi = Aree.Codice_Abbreviato + SottoAree.Codice_Abbreviato + Componenti.Codice_Abbreviato
				,@SottoComponente = SottoComponenti.Codice_Abbreviato 
				,@Partizione = Partizioni.Codice_Abbreviato
				,@Id_Plc = Componenti.Id_Plc
		FROM	Partizioni
				INNER JOIN	SottoComponenti ON SottoComponenti.Id_SottoComponente = Partizioni.Id_SottoComponente
				INNER JOIN	Componenti ON	Componenti.Id_Componente = SottoComponenti.Id_Componente
				INNER JOIN	SottoAree ON SottoAree.Id_SottoArea = Componenti.Id_SottoArea
				INNER JOIN	Aree ON Aree.Id_Area = SottoAree.Id_Area
		WHERE	Partizioni.Id_Partizione = @Id_Partizione
		
		-- Creazione del messaggio.	
		SET @XmlMessage = '<ClusterComminication/>'
		SET @XmlMessage.modify('insert <HeaderLen>32</HeaderLen> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <SysCode>APCV3</SysCode> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <OpType>1</OpType> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <OpCode>1</OpCode> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <OpProgressId>0</OpProgressId> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <DataCluster/> into (//ClusterComminication)[1]')
		
		SET @XmlMessage.modify('insert <Asi>{sql:variable("@Asi")}</Asi> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <SubItem>{sql:variable("@SottoComponente")}</SubItem> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <Partition>{sql:variable("@Partizione")}</Partition> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <MsgId>{sql:variable("@MsgId")}</MsgId> into (//DataCluster)[1]')
		
		-- UdcId ed UdcCode li lascio a zero, tanto non mi servono, evito di recuperare i dati.
		SET @XmlMessage.modify('insert <TypeMessage id="{sql:variable("@MsgId")}" /> into (//DataCluster)[1]')
		
		-- Scrittura del messaggio nella Base Dati.
		EXEC @Return = sp_Insert_Messaggi	@Id_Messaggio = @Id_Messaggio OUTPUT
											,@Id_Tipo_Direzione_Messaggio = 'S'
											,@XmlMessage = @XmlMessage
											,@Id_Plc = @Id_Plc
											,@Id_Tipo_Stato_Messaggio = 1
											,@Id_Processo = @Id_Processo
											,@Origine_Log = @Origine_Log
											,@Id_Utente = @Id_Utente
											,@Errore = @Errore OUTPUT		
		IF @Return <> 0 RAISERROR(@Errore,12,1)
		
		-- Valorizzo il parametro Gmove_Id nell'Xml x farlo recuperare al PCM
		UPDATE	Messaggi_Inviati 
		SET		Messaggio.modify('insert <LuDataRqToAsi_Id>{sql:variable("@Id_Messaggio")}</LuDataRqToAsi_Id> into (//TypeMessage)[1]')
		WHERE	Id_Messaggio = @Id_Messaggio
				
		-- Inserisco l'associazione Messaggio - Missione				
		IF @Id_Missione IS NOT NULL AND @Sequenza_Percorso IS NOT NULL
		BEGIN
			INSERT INTO Messaggi_Percorsi (Id_Messaggio,Id_Percorso,Sequenza_Percorso,Id_Udc)
			VALUES	(@Id_Messaggio,@Id_Missione,@Sequenza_Percorso,@Id_Udc)
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
		END
		-- Return 0 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END




GO
