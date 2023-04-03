SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_CreaMsg_ItemCommand]
@Id_Partizione		Int	
,@CommandCode		Int
,@Command_Param_0	Int = 0
,@Command_Param_1	Int = 0
,@Command_Param_2	Int = 0
,@Command_Param_3	Int = 0
,@Command_Param_4	Int = 0
,@Command_Param_5	Int = 0
,@Command_Param_6	Int = 0
,@Command_Param_7	Int = 0
,@Command_Param_8	Int = 0
,@Command_Param_9	Int = 0
-- Parametri Standard;
,@Id_Processo		Varchar(30)	
,@Origine_Log		Varchar(25)	
,@Id_Utente			Varchar(32)		
,@Errore			Varchar(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	-- SET LOCK_TIMEOUT

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
		DECLARE	@Asi Varchar(4)
		DECLARE @SottoComponente Varchar(4)
		DECLARE	@Partizione	Varchar(4)
		DECLARE @XmlMessage xml
		DECLARE @Id_Plc Int
		--DECLARE	@MsgLen	Int
		DECLARE	@MsgId	Int
		DECLARE @Command_Param_N INT = 0

		-- Inserimento del codice;
		--SET @MsgLen = 16
		SET @MsgId = 12002 -- id nuovo a 5 cifre.

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
		--SET @XmlMessage.modify('insert <MsgLen>{sql:variable("@MsgLen")}</MsgLen> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <MsgId>{sql:variable("@MsgId")}</MsgId> into (//DataCluster)[1]')
		SET @XmlMessage.modify('insert <TypeMessage id="{sql:variable("@MsgId")}" /> into (//DataCluster)[1]')

		SET @XmlMessage.modify('insert <CommandCode>{sql:variable("@CommandCode")}</CommandCode> into (//TypeMessage)[1]')
		
		IF @Command_Param_0 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_0>{sql:variable("@Command_Param_0")}</Command_Param_0> into (//TypeMessage)[1]') 
			SET @Command_Param_N  += 1
		END

		IF @Command_Param_1 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_1>{sql:variable("@Command_Param_1")}</Command_Param_1> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END 
			
		IF @Command_Param_2 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_2>{sql:variable("@Command_Param_2")}</Command_Param_2> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END

		IF @Command_Param_3 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_3>{sql:variable("@Command_Param_3")}</Command_Param_3> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END

		IF @Command_Param_4 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_4>{sql:variable("@Command_Param_4")}</Command_Param_4> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END

		IF @Command_Param_5 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_5>{sql:variable("@Command_Param_5")}</Command_Param_5> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END

		
		IF @Command_Param_6 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_6>{sql:variable("@Command_Param_6")}</Command_Param_6> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END

		IF @Command_Param_7 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_7>{sql:variable("@Command_Param_7")}</Command_Param_7> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END

		IF @Command_Param_8 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_8>{sql:variable("@Command_Param_8")}</Command_Param_8> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END

		IF @Command_Param_9 <> 0
		BEGIN  
			SET @XmlMessage.modify('insert <Command_Param_9>{sql:variable("@Command_Param_9")}</Command_Param_9> into (//TypeMessage)[1]')
			SET @Command_Param_N  += 1
		END
				
		SET @XmlMessage.modify('insert <Command_Param_N>{sql:variable("@Command_Param_N")}</Command_Param_N> into (//TypeMessage)[1]')
		
		-- Scrittura del messaggio nella Base Dati.
		EXEC @Return = sp_Insert_Messaggi	@Id_Tipo_Direzione_Messaggio = 'S'
											,@XmlMessage = @XmlMessage
											,@Id_Plc = @Id_Plc
											,@Id_Tipo_Stato_Messaggio = 1
											,@Id_Processo = @Id_Processo
											,@Origine_Log = @Origine_Log
											,@Id_Utente = @Id_Utente
											,@Errore = @Errore OUTPUT
		IF @Return <> 0 RAISERROR(@Errore,12,1)
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
