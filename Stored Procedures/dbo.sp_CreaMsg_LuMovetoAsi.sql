SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[sp_CreaMsg_LuMovetoAsi]
@Handling_Mode Int = NULL
,@Xml_Param Xml
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
		DECLARE	@MsgId	Int
		DECLARE @Cursore CURSOR
		DECLARE @Count Int
		DECLARE @Id_LU Int
		DECLARE @ID_COMPONENTE_SORGENTE INT
		DECLARE @Id_Partizione_Sorgente Int 
		DECLARE @Tipo_Partizione_Sorgente Varchar(2)
		DECLARE @ID_COMPONENTE_DESTINAZIONE INT
		DECLARE @Id_Partizione_Destinazione Int
		DECLARE @Tipo_Partizione_Destinazione Varchar(2)
		DECLARE @Xml Varchar(MAX)
		DECLARE @Numero_Udc Int
		DECLARE @Xml_Pacchetto Varchar(MAX)
		DECLARE @Asi_Sorgente Varchar(4)
		DECLARE @SottoComponente_Sorgente Varchar(4)
		DECLARE @Partizione_Sorgente Varchar(4)
		DECLARE @Asi_Destinazione Varchar(4)
		DECLARE @SottoComponente_Destinazione Varchar(4)
		DECLARE @Partizione_Destinazione Varchar(4)
		DECLARE @Id_Plc_Sorg Int
		DECLARE @Id_Plc_Dest Int
		DECLARE @Id_Plc Int
		DECLARE @Id_Missione Int
		DECLARE @Sequenza_Percorso Int
		DECLARE @Id_Messaggio Int	
		DECLARE @Messaggi_Percorsi TABLE (Id_Missione Int, Sequenza_Percorso Int, Id_Udc Int)
		
		-- Inserimento del codice;
		SET @MsgId	= 12020
				
		SET @Cursore = CURSOR LOCAL FAST_FORWARD FOR
		SELECT	Parametri.Id_LU
				,Parametri.Id_Missione
				,Parametri.Sequenza_Percorso
				,Parametri.ID_COMPONENTE_SORGENTE
				,Parametri.Id_Partizione_Sorgente
				,Tipo_Partizione_Sorgente
				,Parametri.ID_COMPONENTE_DESTINAZIONE
				,Parametri.Id_Partizione_Destinazione
				,Parametri.Tipo_Partizione_Destinazione
		FROM	(SELECT	Parametri.Colonna.value('@Id_LU','Int')AS Id_LU
						,Parametri.Colonna.value('@ID_COMPONENTE_SORGENTE','Int')AS ID_COMPONENTE_SORGENTE
						,Parametri.Colonna.value('@Id_Partizione_Sorgente','Int')AS Id_Partizione_Sorgente
						,Parametri.Colonna.value('@Tipo_Partizione_Sorgente','Varchar(2)')AS Tipo_Partizione_Sorgente
						,Parametri.Colonna.value('@ID_COMPONENTE_DESTINAZIONE','Int')AS ID_COMPONENTE_DESTINAZIONE
						,Parametri.Colonna.value('@Id_Partizione_Destinazione','Int')AS Id_Partizione_Destinazione
						,Parametri.Colonna.value('@Tipo_Partizione_Destinazione','Varchar(2)')AS Tipo_Partizione_Destinazione
						,Parametri.Colonna.value('@Id_Missione','Int')AS Id_Missione
						,Parametri.Colonna.value('@Sequenza_Percorso','Int')AS Sequenza_Percorso
				FROM	@Xml_Param.nodes('/Parametri/LU_Itinerary') Parametri(Colonna)) Parametri
								
		-- Creazione del messaggio.
		SET @Xml = '<ClusterCommunication>'
		SET @Xml = @Xml + '<HeaderLen>32</HeaderLen>' 
		SET @Xml = @Xml + '<SysCode>APCV3</SysCode>' 
		SET @Xml = @Xml + '<OpType>1</OpType>' 
		SET @Xml = @Xml + '<OpCode>1</OpCode>' 
		SET @Xml = @Xml + '<OpProgressId>0</OpProgressId>' 
		SET @Xml = @Xml + '<DataCluster>'
		
		OPEN @Cursore
		
		FETCH NEXT FROM @Cursore INTO
		@Id_LU
		,@Id_Missione
		,@Sequenza_Percorso
		,@ID_COMPONENTE_SORGENTE
		,@Id_Partizione_Sorgente
		,@Tipo_Partizione_Sorgente 
		,@ID_COMPONENTE_DESTINAZIONE
		,@Id_Partizione_Destinazione
		,@Tipo_Partizione_Destinazione
		WHILE @@FETCH_STATUS = 0 
		BEGIN	
			-- Bisogna inserire qui il record d associazione Messaggio - Missione - Percorso
			IF @@FETCH_STATUS = 0
			BEGIN
				INSERT INTO @Messaggi_Percorsi (Id_Missione,Sequenza_Percorso,Id_Udc)
				VALUES (@Id_Missione,@Sequenza_Percorso,@Id_LU)
			END

			SELECT	@Asi_Sorgente = Aree.CODICE_ABBREVIATO + SottoAree.CODICE_ABBREVIATO + Componenti.CODICE_ABBREVIATO
					,@SottoComponente_Sorgente = SottoComponenti.CODICE_ABBREVIATO
					,@Partizione_Sorgente = Partizioni.CODICE_ABBREVIATO
			FROM	Partizioni
					INNER JOIN SottoComponenti ON SottoComponenti.ID_SOTTOCOMPONENTE = Partizioni.ID_SOTTOCOMPONENTE
					INNER JOIN Componenti ON Componenti.ID_COMPONENTE = SottoComponenti.ID_COMPONENTE
					INNER JOIN SottoAree ON SottoAree.ID_SOTTOAREA = Componenti.ID_SOTTOAREA
					INNER JOIN Aree ON Aree.ID_AREA = SottoAree.ID_AREA 
			WHERE	Id_Partizione = @Id_Partizione_Sorgente 

			SELECT	@Asi_Destinazione = Aree.CODICE_ABBREVIATO + SottoAree.CODICE_ABBREVIATO + Componenti.CODICE_ABBREVIATO
					,@SottoComponente_Destinazione = SottoComponenti.CODICE_ABBREVIATO
					,@Partizione_Destinazione = Partizioni.CODICE_ABBREVIATO
			FROM	Partizioni
					INNER JOIN SottoComponenti ON SottoComponenti.ID_SOTTOCOMPONENTE = Partizioni.ID_SOTTOCOMPONENTE
					INNER JOIN Componenti ON Componenti.ID_COMPONENTE = SottoComponenti.ID_COMPONENTE
					INNER JOIN SottoAree ON SottoAree.ID_SOTTOAREA = Componenti.ID_SOTTOAREA
					INNER JOIN Aree ON Aree.ID_AREA = SottoAree.ID_AREA			
			WHERE	Id_Partizione = @Id_Partizione_Destinazione

			SET @Count = ISNULL(@Count,0) + 1
						
			IF @Count = 1
			BEGIN
				IF @Tipo_Partizione_DestinazIone = 'TR' AND @TIPO_PARTIZIONE_SORGENTE <> 'TR'
				BEGIN
					SELECT	@Id_Plc = Componenti.ID_PLC 
					FROM	Componenti 
					WHERE	ID_COMPONENTE = @ID_COMPONENTE_DESTINAZIONE

					SET @Xml_Pacchetto = '<Asi>' + @Asi_Destinazione + '</Asi>'
					SET @Xml_Pacchetto = @Xml_Pacchetto + '<SubItem>' + @SottoComponente_Destinazione + '</SubItem>'
					SET @Xml_Pacchetto = @Xml_Pacchetto + '<Partition>' + @Partizione_Destinazione + '</Partition>'
				END
				ELSE
				BEGIN
					SELECT	@Id_Plc = Componenti.ID_PLC 
					FROM	Componenti 
					WHERE	ID_COMPONENTE = @ID_COMPONENTE_SORGENTE

					SET @Xml_Pacchetto = '<Asi>' + @Asi_Sorgente + '</Asi>'
					SET @Xml_Pacchetto = @Xml_Pacchetto + '<SubItem>' + @SottoComponente_Sorgente + '</SubItem>'
					SET @Xml_Pacchetto = @Xml_Pacchetto + '<Partition>' + @Partizione_Sorgente + '</Partition>'
				END

				SET @Xml_Pacchetto = @Xml_Pacchetto + '<MsgId>' + CONVERT(Varchar,@MsgId) + '</MsgId>'
				SET @Xml_Pacchetto = @Xml_Pacchetto + '<TypeMessage id="' + CONVERT(Varchar,@MsgId) + '">' 
				--HANDLING MODE CHE PER IL TRASLO ASSUME VALORE DI QUOTA DEPOSITO
				SET @Xml_Pacchetto = @Xml_Pacchetto + '<HANDLING_MODE>' + CONVERT(Varchar,@Handling_Mode) + '</HANDLING_MODE>'
			END
			--CUSTOM ADIGE 
			--SETTO LA HANDLING MODE SPECIFICA PER IL TIPO DI UDC, Tipo= 
			DECLARE @HandligModeUdc int = NULL
			SELECT @HandligModeUdc = tu.Handling_Mode FROM Tipo_Udc tu 
			WHERE tu.Id_Tipo_Udc = (SELECT Id_Tipo_Udc FROM Udc_Testata WHERE Id_Udc = @Id_LU)						
		
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_ID_' + CONVERT(Varchar,@Count) + '>' + CONVERT(Varchar,ISNULL(@Id_LU,'')) + '</LU_ID_' + CONVERT(Varchar,@Count) + '>'
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_HANDLING_MODE_' + CONVERT(Varchar,@Count) + '>' + CONVERT(Varchar,ISNULL(@HandligModeUdc,'')) + '</LU_HANDLING_MODE_' + CONVERT(Varchar,@Count) + '>'
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_SOURCE_ASI_' + CONVERT(Varchar,@Count) + '>' + @Asi_Sorgente + '</LU_SOURCE_ASI_' + CONVERT(Varchar,@Count) + '>'
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_SOURCE_SUBITEM_' + CONVERT(Varchar,@Count) + '>' + @SottoComponente_Sorgente + '</LU_SOURCE_SUBITEM_' + CONVERT(Varchar,@Count) + '>'		
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_SOURCE_PARTITION_' + CONVERT(Varchar,@Count) + '>' + @Partizione_Sorgente + '</LU_SOURCE_PARTITION_' + CONVERT(Varchar,@Count) + '>'
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_DEST_ASI_' + CONVERT(Varchar,@Count) + '>' + @Asi_Destinazione + '</LU_DEST_ASI_' + CONVERT(Varchar,@Count) + '>'
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_DEST_SUBITEM_' + CONVERT(Varchar,@Count) + '>' + @SottoComponente_Destinazione + '</LU_DEST_SUBITEM_' + CONVERT(Varchar,@Count) + '>'		
			SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_DEST_PARTITION_' + CONVERT(Varchar,@Count) + '>' + @Partizione_Destinazione+ '</LU_DEST_PARTITION_' + CONVERT(Varchar,@Count) + '>'																																										
					
			SET @Id_Lu = NULL			
			SET @Asi_Sorgente = NULL
			SET @SottoComponente_Sorgente = NULL
			SET @Partizione_Sorgente = NULL
			SET @Asi_Destinazione = NULL
			SET @SottoComponente_Destinazione = NULL
			SET @Partizione_Destinazione = NULL
									
			FETCH NEXT FROM @Cursore INTO
			@Id_LU
			,@Id_Missione
			,@Sequenza_Percorso
			,@ID_COMPONENTE_SORGENTE
			,@Id_Partizione_Sorgente
			,@Tipo_Partizione_Sorgente 
			,@ID_COMPONENTE_DESTINAZIONE
			,@Id_Partizione_Destinazione
			,@Tipo_Partizione_Destinazione
		END
		
		CLOSE @Cursore
		DEALLOCATE @Cursore

		SET @Xml_Pacchetto = @Xml_Pacchetto + '<LU_NO>' + CONVERT(Varchar,@Count) + '</LU_NO>'

		SET @Xml_Pacchetto = @Xml + @Xml_Pacchetto + '</TypeMessage></DataCluster></ClusterCommunication>'
																
		-- Scrittura del messaggio nella Base Dati.
		EXEC @Return = sp_Insert_Messaggi	@Id_Messaggio = @Id_Messaggio OUTPUT
											,@Id_Tipo_Direzione_Messaggio = 'S'
											,@XmlMessage = @Xml_Pacchetto
											,@Id_Plc = @Id_Plc
											,@Id_Tipo_Stato_Messaggio = 1
											,@Id_Processo = @Id_Processo
											,@Origine_Log = @Origine_Log
											,@Id_Utente = @Id_Utente
											,@Errore = @Errore OUTPUT
		IF @Return <> 0 RAISERROR(@Errore,12,1)
				
		-- Valorizzo il parametro Gmove_Id nell'Xml x farlo recuperare al PCM
		UPDATE	Messaggi_Inviati 
		SET		Messaggio.modify('insert <LU_MOVE_ID>{sql:variable("@Id_Messaggio")}</LU_MOVE_ID> into (//TypeMessage)[1]')
		WHERE	Id_Messaggio = @Id_Messaggio
				
		-- Inserisco l'associazione Messaggio - Missione				
		INSERT INTO Messaggi_Percorsi (Id_Messaggio,Id_Percorso,Sequenza_Percorso,Id_Udc)
		SELECT	@Id_Messaggio,Id_Missione,Sequenza_Percorso,Id_Udc
		FROM	@Messaggi_Percorsi
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
