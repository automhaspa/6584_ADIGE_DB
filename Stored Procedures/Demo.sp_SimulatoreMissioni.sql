SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE PROCEDURE [Demo].[sp_SimulatoreMissioni]
-- Parametri Standard;
@Id_Processo		VARCHAR(30)	
,@Origine_Log		VARCHAR(25)	
,@Id_Utente			VARCHAR(16)		
,@Errore			VARCHAR(500) OUTPUT
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT OFF
	-- SET LOCK_TIMEOUT

	-- Dichiarazioni variabili standard;
	DECLARE @Nome_StoredProcedure VARCHAR(30)
	DECLARE @TranCount INT
	DECLARE @Return INT
	DECLARE @ErrLog VARCHAR(500)
	-- Settaggio della variabile che indica il nome delle procedura in esecuzione;
	SET @Nome_StoredProcedure = OBJECT_NAME(@@ProcId) 
	-- Salvataggio del numero d transazioni aperte al momento dello start della procedura;
	SET @TranCount = @@TRANCOUNT
	-- Se il numero di transazioni è 0 significa ke devo aprirla, altrimenti ne salvo una nidificata;
	IF @TranCount = 0 BEGIN TRANSACTION

	BEGIN TRY	
		-- Dichiarazioni Variabili;
		DECLARE @Cursor_PendingSteps		CURSOR
		DECLARE @Id_Udc_C					NUMERIC(18,0)
		DECLARE @Id_Partizione_C			INT
		DECLARE @Sequenza_Percorso_C		INT
		DECLARE @Id_Tipo_Stato_Percorso_C	INT
		DECLARE @Id_Tipo_Messaggio_C		INT
		DECLARE @Id_Missione_C				INT
		DECLARE @Id_Messaggio_C				INT

		DECLARE @XmlMessage					XML
		DECLARE @Id_Messaggio				INT
		DECLARE @Asi						VARCHAR(4)
		DECLARE @SottoComponente			VARCHAR(4)
		DECLARE @Partizione					VARCHAR(4)
		DECLARE @Id_Plc						INT
		DECLARE @Height						INT
		DECLARE @Length						INT
		DECLARE @Width						INT
		DECLARE @Weight						INT
		DECLARE @Id_Tipo_Udc				VARCHAR(1)
		DECLARE	@Flag_Parametri_Generali	BIT

		-- Inserimento del codice;	

		SELECT	@Flag_Parametri_Generali = CAST(pg.Valore AS BIT)
		FROM	dbo.Parametri_Generali AS pg
		WHERE	pg.Id_Parametro = 'Demo_CS'  

		-- SETTO IL CURSORE CON I PASSI DELLE MISSIONI IN ESECUZIONE
		SET @Cursor_PendingSteps = CURSOR LOCAL FAST_FORWARD FOR
			SELECT		M.Id_Udc,
						ISNULL(P.Id_Partizione_Destinazione,UP.Id_Partizione) AS Id_Partizione,
						P.Sequenza_Percorso,
						P.Id_Tipo_Stato_Percorso,
						P.Id_Tipo_Messaggio,
						M.Id_Missione,
						MP.Id_Messaggio AS Id_Messaggio_Inviato
			FROM		dbo.Missioni M INNER JOIN dbo.Percorso P ON P.Id_Percorso = M.Id_Missione
			INNER JOIN	dbo.Messaggi_Percorsi MP ON MP.Id_Percorso = P.Id_Percorso AND MP.Sequenza_Percorso = P.Sequenza_Percorso
			INNER JOIN	dbo.Udc_Posizione UP ON M.Id_Udc = UP.Id_Udc
			LEFT JOIN	dbo.Messaggi_Ricevuti MR ON MR.MESSAGGIO.value('data(//LuDataRqToAsi_Id)[1]','INT') = MP.Id_Messaggio
			WHERE		M.Id_Stato_Missione = 'ESE' --LA MISSIONE DEVE ESSERE IN ESECUZIONE
			AND			P.Id_Tipo_Stato_Percorso = 2 --IL PERCORSO DEVE ESSERE IN STATO DI ESECUZIONE
			AND			ISNULL(MR.ID_MESSAGGIO,0) = 0 --NON CI DEVE ESSERE UN MESSAGGIO RICEVUTO ASSOCIATO AL MESSAGGIO INVIATO
			ORDER BY	M.Priorita DESC	


		OPEN @Cursor_PendingSteps
		FETCH NEXT FROM @Cursor_PendingSteps INTO 			
			@Id_Udc_C,
			@Id_Partizione_C,
			@Sequenza_Percorso_C,
			@Id_Tipo_Stato_Percorso_C,
			@Id_Tipo_Messaggio_C,
			@Id_Missione_C,
			@Id_Messaggio_C

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF(@Id_Tipo_Messaggio_C = 11031) --SE SI TRATTA DI UN CONTROLLO SAGOMA ALLORA PRENDO I DATI CHE MI SERVONO PER CREARE IL MESSAGGIO DI RITORNO E ESEGUIRE LA STORED PROCEDURE
					BEGIN
						-- Recupero ASI, SOTTOCOMPONENTE, PARTIZIONE ed Id_Plc partendo dalla partizione passata come parametro.
						SELECT	@Asi = A.Codice_Abbreviato + SA.Codice_Abbreviato + C.Codice_Abbreviato
								,@SottoComponente = SC.Codice_Abbreviato 
								,@Partizione = P.Codice_Abbreviato
								,@Id_Plc = C.Id_Plc
						FROM	dbo.Partizioni P
								INNER JOIN	dbo.SottoComponenti SC ON SC.Id_SottoComponente = P.Id_SottoComponente
								INNER JOIN	dbo.Componenti C ON C.Id_Componente = SC.Id_Componente
								INNER JOIN	dbo.SottoAree SA ON SA.Id_SottoArea = C.Id_SottoArea
								INNER JOIN	dbo.Aree A ON A.Id_Area = SA.Id_Area
						WHERE	P.Id_Partizione = @Id_Partizione_C
	
						-- RECUPERO IL TIPO UDC DELL'UDC IN QUESTIONE
						SELECT	@Id_Tipo_Udc = Id_Tipo_Udc
						FROM	dbo.Udc_Testata UT
						WHERE	UT.Id_Udc = @Id_Udc_C

						--SE L'ID_TIPO_UDC E' DIVERSO DA 'N' (NON DEFINITO) ALLORA PRENDO I PARAMETRI VOLUMETRICI DALL'UDC STESSA
						IF(@Id_Tipo_Udc <> 'N')
							BEGIN
								SELECT	@Height = CASE @Flag_Parametri_Generali WHEN 1 THEN 9999 ELSE UT.Altezza END,
										@Length = UT.Profondita,
										@Width = UT.Larghezza,
										@Weight = UT.Peso
								FROM	dbo.Udc_Testata UT
								WHERE	UT.Id_Udc = @Id_Udc_C
							END
						--SE IL CONTROLLO SAGOMA E' IN 5A03 ALLORA BISOGNA PASSARE A 0 I VALORI IN QUANTO LI C'E' L'INGRESSO DI UDC VUOTE
						ELSE IF(@Id_Partizione_C = 142 AND @Height IS NULL)	
							BEGIN
								SET @Height = CASE @Flag_Parametri_Generali WHEN 1 THEN 9999 ELSE 0 END
								SET @Length = 0
								SET @Width = 0
								SET @Weight = 0 
							END
						--SE INVECE L'ID_TIPO_UDC E' UGUALE A 'N' ALLORA PRENDO DEI VALORI STANDARD IN BASE AL MAGAZZINO IN CUI MI TROVO
						ELSE
							BEGIN
								SET @Height = CASE @Flag_Parametri_Generali WHEN 1 THEN 9999 ELSE 2430 END
								SET @Length = 800
								SET @Width = 1200
								SET @Weight = 899
							END
						
						--SETTO IL PARAMETRO XMLMESSAGE CON L'ARCHITETTURA DI CUI HA BISOGNO.
						SET @XmlMessage = '<ClusterComminication/>'
						SET @XmlMessage.modify('insert <HeaderLen>32</HeaderLen> into (//ClusterComminication)[1]')
						SET @XmlMessage.modify('insert <SysCode>APCV3</SysCode> into (//ClusterComminication)[1]')
						SET @XmlMessage.modify('insert <OpType>1</OpType> into (//ClusterComminication)[1]')
						SET @XmlMessage.modify('insert <OpCode>1</OpCode> into (//ClusterComminication)[1]')
						SET @XmlMessage.modify('insert <OpProgressId>0</OpProgressId> into (//ClusterComminication)[1]')
						SET @XmlMessage.modify('insert <DataCluster/> into (//ClusterComminication)[1]')
						------------------------------------------------------------------------------------------------------------------
						SET @XmlMessage.modify('insert <Asi>{sql:variable("@Asi")}</Asi> into (//DataCluster)[1]')
						SET @XmlMessage.modify('insert <SubItem>{sql:variable("@SottoComponente")}</SubItem> into (//DataCluster)[1]')
						SET @XmlMessage.modify('insert <Partition>{sql:variable("@Partizione")}</Partition> into (//DataCluster)[1]')
						SET @XmlMessage.modify('insert <MsgId>11031</MsgId> into (//DataCluster)[1]')
						SET @XmlMessage.modify('insert <TypeMessage id="11031" /> into (//DataCluster)[1]')
						------------------------------------------------------------------------------------------------------------------
						SET @XmlMessage.modify('insert <LU_DATA_CONFIRM>1</LU_DATA_CONFIRM> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_DATA_ERROR_CODE>0</LU_DATA_ERROR_CODE> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LuDataRqToAsi_Id>{sql:variable("@Id_Messaggio_C")}</LuDataRqToAsi_Id> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_ID>{sql:variable("@Id_Udc_C")}</LU_ID> into (//TypeMessage)[1]')

						SET @XmlMessage.modify('insert <LU_CONTAINER_TYPE>0</LU_CONTAINER_TYPE> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_CONTAINER_SIZE_HEIGTH>0</LU_CONTAINER_SIZE_HEIGTH> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_CONTAINER_SIZE_LENGTH>0</LU_CONTAINER_SIZE_LENGTH> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_CONTAINER_SIZE_WIDTH>0</LU_CONTAINER_SIZE_WIDTH> into (//TypeMessage)[1]')

						SET @XmlMessage.modify('insert <LU_HEIGHT>{sql:variable("@Height")}</LU_HEIGHT> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_LENGTH>{sql:variable("@Length")}</LU_LENGTH> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_WIDTH>{sql:variable("@Width")}</LU_WIDTH> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_WEIGTH>{sql:variable("@Weight")}</LU_WEIGTH> into (//TypeMessage)[1]')

						SET @XmlMessage.modify('insert <LU_TEMP>0</LU_TEMP> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_LENGTH_SIDE_1_SURPLUS>0</LU_LENGTH_SIDE_1_SURPLUS> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_LENGTH_SIDE_2_SURPLUS>0</LU_LENGTH_SIDE_2_SURPLUS> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_WIDTH_SIDE_1_SURPLUS>0</LU_WIDTH_SIDE_1_SURPLUS> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_WIDTH_SIDE_2_SURPLUS>0</LU_WIDTH_SIDE_2_SURPLUS> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_HEIGTH_SURPLUS>0</LU_HEIGTH_SURPLUS> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_1>0</LU_SPARE_DIM_1> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_2>0</LU_SPARE_DIM_2> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_3>0</LU_SPARE_DIM_3> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_4>0</LU_SPARE_DIM_4> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_5>0</LU_SPARE_DIM_5> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_6>0</LU_SPARE_DIM_6> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_7>0</LU_SPARE_DIM_7> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_8>0</LU_SPARE_DIM_8> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_9>0</LU_SPARE_DIM_9> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_SPARE_DIM_10>0</LU_SPARE_DIM_10> into (//TypeMessage)[1]')
						SET @XmlMessage.modify('insert <LU_CODE /> into (//TypeMessage)[1]')
						------------------------------------------------------------------------------------------------------------------
						SET @XmlMessage.modify('insert <DataCrc>3387250456</DataCrc>  into (//ClusterComminication)[1]')
						SET @XmlMessage.modify('insert <DataSent>208</DataSent> into (//ClusterComminication)[1]')

						--INSERISCO IL MESSAGGIO NELLA TABELLA MESSAGGI_RICEVUTI
						EXEC dbo.sp_Insert_Messaggi	@Id_Tipo_Direzione_Messaggio = 'R'
													,@XmlMessage = @XmlMessage
													,@Id_Plc = @Id_Plc
													,@Id_Tipo_Stato_Messaggio = 1
													,@Id_Messaggio = @Id_Messaggio OUTPUT
													,@Id_Processo = @Id_Processo
													,@Origine_Log = @Origine_Log
													,@Id_Utente = @Id_Utente
													,@Errore = @Errore OUTPUT	


					END	
				ELSE --IF (@Id_Tipo_Messaggio_C = 12020) --SE SI TRATTA DI UN MOVE LU ALLORA METTO IL PASSO IN STATO 3 E BON
					BEGIN
						EXEC dbo.sp_Update_Aggiorna_Posizione_Udc @Id_Udc = @Id_Udc_C,
																			@Id_Partizione = @Id_Partizione_C,
																			@Sequenza_Percorso = @Sequenza_Percorso_C,
																			@Id_Stato_Percorso = 3,
																			@Id_Missione = @Id_Missione_C,
																			@Id_Processo = @Id_Processo,
																			@Origine_Log = @Origine_Log,
																			@Id_Utente = @Id_Utente,
																			@SavePoint = '',
																			@Errore = @Errore OUTPUT

					END	
				
				FETCH NEXT FROM @Cursor_PendingSteps INTO 			
					@Id_Udc_C,
					@Id_Partizione_C,
					@Sequenza_Percorso_C,
					@Id_Tipo_Stato_Percorso_C,
					@Id_Tipo_Messaggio_C,
					@Id_Missione_C,
					@Id_Messaggio_C
			END

		CLOSE @Cursor_PendingSteps
		DEALLOCATE @Cursor_PendingSteps
		-- Fine del codice;

		-- Eseguo il commit solo se sono la procedura iniziale che ha iniziato la transazione;
		IF @TranCount = 0 COMMIT TRANSACTION
		-- Return 0 se tutto è andato a buon fine;
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
		-- Return 1 se la procedura è andata in errore;
		RETURN 1
	END CATCH
END

GO
