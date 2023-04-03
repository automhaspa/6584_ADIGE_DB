SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_CreaMsg_MoveItem]
@Id_Missione Int
,@Sequenza_Percorso Int
,@Id_Componente_Macchina Int
,@Id_Partizione_Destinazione Int	
,@RefParam1 Varchar(4) = '0000'
,@RefParam2 Varchar(4) = '0000'
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
		DECLARE	@MsgLen	Int
		DECLARE	@MsgId	Int
		DECLARE	@Asi_Destinazione Varchar(4)
		DECLARE @SottoComponente_Destinazione	Varchar(4)
		DECLARE	@Partizione_Destinazione	Varchar(4)
		DECLARE	@Asi Varchar(4)
		DECLARE @XmlMessage xml
		DECLARE @PosType Int
		DECLARE @MoveType Int
		DECLARE @Id_Plc Int
		DECLARE @Id_Messaggio Int

		-- Inserimento del codice;
		SET @MsgLen =	13
		SET @MsgId =	1219
		SET @PosType =	2 -- Impianto
		SET @MoveType =	0 -- Default	
		SET @RefParam1 = '0000'
		SET @RefParam2 = '0000'	

		SELECT	@Asi_Destinazione = Aree.Codice_Abbreviato + SottoAree.Codice_Abbreviato + Componenti.Codice_Abbreviato
				,@SottoComponente_Destinazione = SottoComponenti.Codice_Abbreviato 
				,@Partizione_Destinazione = Partizioni.Codice_Abbreviato
		FROM	Partizioni
				INNER JOIN	SottoComponenti ON SottoComponenti.Id_SottoComponente = Partizioni.Id_SottoComponente
				INNER JOIN	Componenti ON	Componenti.Id_Componente = SottoComponenti.Id_Componente
				INNER JOIN	SottoAree ON SottoAree.Id_SottoArea = Componenti.Id_SottoArea
				INNER JOIN	Aree ON Aree.Id_Area = SottoAree.Id_Area
		WHERE	Partizioni.Id_Partizione = @Id_Partizione_Destinazione

		SELECT	@Asi = Aree.Codice_Abbreviato + SottoAree.Codice_Abbreviato + Componenti.Codice_Abbreviato
				,@Id_Plc = Id_Plc
		FROM	Componenti
				INNER JOIN	SottoAree ON SottoAree.Id_SottoArea = Componenti.Id_SottoArea
				INNER JOIN	Aree ON Aree.Id_Area = SottoAree.Id_Area
		WHERE	Componenti.Id_Componente = @Id_Componente_Macchina

		-- Creazione del messaggio.
		SET @XmlMessage = '<ClusterComminication/>'
		SET @XmlMessage.modify('insert <HeaderLen>32</HeaderLen> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <SysCode>APCOM</SysCode> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <OpType>1</OpType> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <OpCode>1</OpCode> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <OpProgressId>0</OpProgressId> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <DataLen>208</DataLen> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <DataSent>208</DataSent> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <DataCluster/> into (//ClusterComminication)[1]')
		SET @XmlMessage.modify('insert <Asi>{sql:variable("@Asi")}</Asi> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <SubItem>0000</SubItem> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <Partition>0000</Partition> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <MsgLen>{sql:variable("@MsgLen")}</MsgLen> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <MsgId>{sql:variable("@MsgId")}</MsgId> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <TypeMessage id="{sql:variable("@MsgId")}" /> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <PosType>{sql:variable("@PosType")}</PosType> into (//TypeMessage)[1]')
		SET @XmlMessage.modify('insert <DestAsi>{sql:variable("@Asi_Destinazione")}</DestAsi> into (//TypeMessage)[1]')
		SET @XmlMessage.modify('insert <DestSubitem>{sql:variable("@SottoComponente_Destinazione")}</DestSubitem> into (//TypeMessage)[1]')
		SET @XmlMessage.modify('insert <DestPartition>{sql:variable("@Partizione_Destinazione")}</DestPartition> into (//TypeMessage)[1]')
		SET @XmlMessage.modify('insert <MoveType>{sql:variable("@MoveType")}</MoveType> into (//TypeMessage)[1]')
		SET @XmlMessage.modify('insert <RefParam1>{sql:variable("@RefParam1")}</RefParam1> into (//TypeMessage)[1]')
		SET @XmlMessage.modify('insert <RefParam2>{sql:variable("@RefParam2")}</RefParam2> into (//TypeMessage)[1]')

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
		SET		Messaggio.modify('insert <MoveItemId>{sql:variable("@Id_Messaggio")}</MoveItemId> into (//TypeMessage)[1]')
		WHERE	Id_Messaggio = @Id_Messaggio
				
		-- Inserisco l'associazione Messaggio - Missione				
		INSERT INTO Messaggi_Percorsi (Id_Messaggio,Id_Percorso,Sequenza_Percorso)
		VALUES	(@Id_Messaggio,@Id_Missione,@Sequenza_Percorso)
		
		-- Prenoto il passo successivo.
		UPDATE	Percorso 
		SET		Id_Componente_Prenotato = @Id_Componente_Macchina
		WHERE	Id_Percorso = @Id_Missione
				AND Sequenza_Percorso = @Sequenza_Percorso + 1
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
