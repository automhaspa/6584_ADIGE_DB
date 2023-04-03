SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROC [dbo].[sp_Cerca_Percorso]
	@Id_Missione				INT			= NULL,
	@Id_Tipo_Missione			VARCHAR(3)	= NULL,
	@Id_Partizione_Sorgente		INT,
	@Id_Partizione_Destinazione INT,
	@Steps						XML,
	-- Parametri Standard;
	@Id_Processo				VARCHAR(30),
	@Origine_Log				VARCHAR(25),
	@Id_Utente					VARCHAR(32),
	@Errore						VARCHAR(500) OUTPUT
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
		DECLARE @WkTable TABLE (Id_Adiacenza INT, Id_Partizione_Sorgente INT,SORGENTE VARCHAR(50),Id_Partizione_Destinazione INT,DESTINAZIONE VARCHAR(50),Descrizione VARCHAR(50),Id_Tipo_Messaggio VARCHAR(5),Direzione CHAR(1),Level INT,RAMO VARCHAR(MAX))
		DECLARE @Id_Percorso_PreCalc INT
        DECLARE @Id_Tipo_Udc VARCHAR(2), @SORG INT, @DEST INT
		DECLARE @Percorso_Calcolato XML
		DECLARE @Count INT
		DECLARE @StoredProcedure VARCHAR(50)
		DECLARE @CURSORE CURSOR
		DECLARE @Descrizione VARCHAR(50)
		DECLARE @Direzione VARCHAR(1)
		DECLARE @Id_Tipo_Messaggio VARCHAR(5)
		DECLARE @Xml_Param XML
		DECLARE @LEVEL INT = 1

		SET @Steps = @Steps.query('//Steps')

		-- Recupero il tipo Udc (mi serve per le esclusioni)
		SELECT	@Id_Tipo_Udc = Udc_Testata.Id_Tipo_Udc
		FROM	Missioni
				INNER JOIN Udc_Testata ON Udc_Testata.Id_Udc = Missioni.Id_Udc
		WHERE	Id_Missione = @Id_Missione		
			
		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	dbo.Partizioni
						WHERE	ID_PARTIZIONE = @Id_Partizione_Sorgente
							AND ID_TIPO_PARTIZIONE = 'MA'
					)
			SELECT	@SORG = ID_PARTIZIONE
			FROM	dbo.Partizioni		P
			JOIN	dbo.SottoComponenti SC
			ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
			WHERE	P.CODICE_ABBREVIATO = '0000'
				AND ID_COMPONENTE = (SELECT ID_COMPONENTE FROM AwmConfig.vPartizioni WHERE ID_PARTIZIONE = @Id_Partizione_Sorgente)

		IF EXISTS	(
						SELECT	TOP 1 1
						FROM	dbo.Partizioni
						WHERE	ID_PARTIZIONE = @Id_Partizione_Destinazione
							AND ID_TIPO_PARTIZIONE = 'MA'
					)
		SELECT	@DEST = ID_PARTIZIONE
		FROM	dbo.Partizioni		P
		JOIN	dbo.SottoComponenti SC
		ON		SC.ID_SOTTOCOMPONENTE = P.ID_SOTTOCOMPONENTE
		WHERE	P.CODICE_ABBREVIATO = '0000'
			AND ID_COMPONENTE = (SELECT ID_COMPONENTE FROM AwmConfig.vPartizioni WHERE ID_PARTIZIONE = @Id_Partizione_Destinazione)

		-- Capisco se il percorso era già satto calcolato in precedenza
		SELECT	@Id_Percorso_PreCalc = PP.Id_Percorso
		FROM	Percorso_PreCalc	PP
		LEFT
		JOIN	(
					SELECT	PP_1.Id_Percorso
					FROM	Percorso_PreCalc	PP_1
					CROSS
					APPLY	Itinerario.nodes('//Percorso') as Tabella(Colonna)
					JOIN	Adiacenze	A
					ON		A.Id_Adiacenza = Tabella.Colonna.value('@Id_Adiacenza', 'Int')  
					WHERE	ISNULL(A.Abilitazione,1) = 0
					GROUP
						BY 	PP_1.Id_Percorso
				) Percorsi_Disabilitati
		ON		Percorsi_Disabilitati.Id_Percorso = PP.Id_Percorso
		WHERE	Id_Partizione_Sorgente = @Id_Partizione_Sorgente
			AND Id_Partizione_Destinazione = @Id_Partizione_Destinazione
			AND Id_Tipo_Udc = @Id_Tipo_Udc
			AND ISNULL(CONVERT(Varchar(MAX),PP.Steps),'') = ISNULL((SELECT CONVERT(Varchar(MAX),@Steps)),'')
			AND Percorsi_Disabilitati.Id_Percorso IS NULL

		IF @Id_Percorso_PreCalc IS NULL
		BEGIN
			INSERT INTO @WkTable (Id_Adiacenza,Id_Partizione_Sorgente,SORGENTE,Id_Partizione_Destinazione,DESTINAZIONE,Descrizione,Id_Tipo_Messaggio,Direzione,Level,RAMO)
			SELECT	Id_Adiacenza,
					Id_Partizione_Sorgente,
					PS.DESCRIZIONE			SORGENTE,
					Id_Partizione_Destinazione,
					PD.DESCRIZIONE			DESTINAZIONE,
					A.Descrizione,
					Id_Tipo_Messaggio,
					Direzione,
					@LEVEL					Level,
					Id_Adiacenza
			FROM	dbo.Adiacenze	A
			JOIN	dbo.Partizioni	PS
			ON		PS.ID_PARTIZIONE = A.Id_Partizione_Sorgente
			JOIN	dbo.Partizioni	PD
			ON		PD.ID_PARTIZIONE = A.Id_Partizione_Destinazione
			WHERE	Id_Partizione_Sorgente = ISNULL(@SORG,@Id_Partizione_Sorgente)
				AND (Id_Tipo_Messaggio = CASE @Id_Tipo_Missione WHEN 'POS' THEN '12010' ELSE '12020' END) -- TEMPORANEO VELOCE
				AND ISNULL(PD.LOCKED,0) = 0
				AND ISNULL(PS.LOCKED,0) = 0

			WHILE 1 = 1
			BEGIN
				INSERT INTO @WkTable
				(
				    Id_Adiacenza,
				    Id_Partizione_Sorgente,
				    SORGENTE,
				    Id_Partizione_Destinazione,
				    DESTINAZIONE,
				    Descrizione,
				    Id_Tipo_Messaggio,
				    Direzione,
				    Level,
				    RAMO
				)
				SELECT	A.Id_Adiacenza,
						A.Id_Partizione_Sorgente,
						PS.DESCRIZIONE SORGENTE,
						A.Id_Partizione_Destinazione,
						PD.DESCRIZIONE DESTINAZIONE,
						A.Descrizione,
						A.Id_Tipo_Messaggio,
						A.Direzione,
						@LEVEL + 1,
						tmp.RAMO + ',' + CAST(A.Id_Adiacenza AS VARCHAR(50))
				FROM	@WkTable		tmp
				JOIN	dbo.Adiacenze	A
				ON		A.Id_Partizione_Sorgente = tmp.Id_Partizione_Destinazione
				JOIN	AwmConfig.vPartizioni	PS
				ON		PS.ID_PARTIZIONE = A.Id_Partizione_Sorgente
				JOIN	dbo.Partizioni			PD
				ON		PD.ID_PARTIZIONE = A.Id_Partizione_Destinazione
				WHERE	Level = @LEVEL
					AND NOT EXISTS (SELECT TOP 1 1 FROM @WkTable TMP WHERE tmp.Id_Adiacenza = A.Id_Adiacenza)
					AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.SplitString(tmp.RAMO,',') WHERE CONVERT(INT,chunk) = A.Id_Adiacenza)
					AND A.Id_Partizione_Sorgente <> ISNULL(@DEST,@Id_Partizione_Destinazione)
					AND ISNULL(Abilitazione,1) = 1
					AND (A.Id_Tipo_Messaggio = CASE @Id_Tipo_Missione WHEN 'POS' THEN '12010' ELSE '12020' END) -- TEMPORANEO VELOCE

				IF @@ROWCOUNT = 0
					OR
					EXISTS (SELECT	TOP 1 1 
							FROM	@WkTable WKT
							WHERE	Level = @LEVEL + 1 
								AND Id_Partizione_Destinazione = ISNULL(@DEST,@Id_Partizione_Destinazione)
								AND (
										ISNULL(CONVERT(VARCHAR(MAX),@Steps),'') = ''
										OR
										NOT EXISTS (
														SELECT	Tabella.Colonna.value('@Id_Partizione', 'Int')
																,T.Id_Partizione_Destinazione
														FROM	@Steps.nodes('//Steps') as Tabella(Colonna)
														LEFT
														JOIN	(
																	SELECT	Id_Partizione_Destinazione 
																	FROM	dbo.SplitString(WKT.RAMO,',') PercorsoCalcolato
																	JOIN	dbo.Adiacenze
																	ON		Id_Adiacenza = PercorsoCalcolato.chunk
																) T
														ON		T.Id_Partizione_Destinazione = Tabella.Colonna.value('@Id_Partizione', 'Int')
														WHERE	T.Id_Partizione_Destinazione IS NULL
													)
									)
							)
					BREAK

				SET @LEVEL += 1
			END

			DECLARE @RAMO VARCHAR(MAX)

			SET @CURSORE = CURSOR LOCAL FAST_FORWARD FOR 
				SELECT	RAMO
				FROM	@WkTable
				WHERE	Id_Partizione_Destinazione = ISNULL(@DEST,@Id_Partizione_Destinazione) 
				ORDER
					BY	Level DESC

			OPEN @CURSORE
			FETCH NEXT FROM @CURSORE INTO
				@RAMO

			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @Steps IS NULL
					OR
					NOT EXISTS	(
									SELECT	Tabella.Colonna.value('@Id_Partizione', 'Int'),
											T.Id_Partizione_Destinazione
									FROM	@Steps.nodes('//Steps') as Tabella(Colonna)
									LEFT
									JOIN	(
												SELECT	Id_Partizione_Destinazione 
												FROM	dbo.SplitString(@RAMO,',') PercorsoCalcolato
												JOIN	dbo.Adiacenze
												ON		Id_Adiacenza = PercorsoCalcolato.chunk
											) T
									ON		T.Id_Partizione_Destinazione = Tabella.Colonna.value('@Id_Partizione', 'Int')
									WHERE	T.Id_Partizione_Destinazione IS NULL
								)
				BEGIN
					SELECT @Percorso_Calcolato = 
					( 
						SELECT	Passo,
								Id_Adiacenza,
								Id_Partizione_Sorgente		Part_Sorgente,
								Id_Partizione_Destinazione	Part_Destinazione,
								Descrizione,
								Id_Tipo_Messaggio
						FROM	dbo.SplitString(@RAMO,',') PercorsoCalcolato
						JOIN	dbo.Adiacenze
						ON		PercorsoCalcolato.chunk = Id_Adiacenza
						FOR XML RAW ('Percorso')
					)
					BEGIN TRY
						INSERT INTO dbo.Percorso_PreCalc
						(
							Id_Partizione_Sorgente,
							Id_Partizione_Destinazione,
							Id_Tipo_Udc,
							Steps,
							Itinerario
						)
						VALUES
						(  
							@Id_Partizione_Sorgente,
							@Id_Partizione_Destinazione,
							@Id_Tipo_Udc,
							@Steps,
							@Percorso_Calcolato
						)
					END TRY
                    BEGIN CATCH
						PRINT 'PERCORSO PRECAALC NON INSERITO'
					END CATCH
				END

				FETCH NEXT FROM @CURSORE INTO
					@RAMO
			END
		END
		ELSE
			-- Se arrivo qui significa che il percorso era già stato trovato in precedenza, quindi non devo + cercarlo e vado a prenderlo nei preCalc
			SELECT	@Percorso_Calcolato = Itinerario
			FROM	Percorso_PreCalc
			WHERE	Id_Percorso = @Id_Percorso_PreCalc

		IF @Percorso_Calcolato IS NULL
		BEGIN
			DECLARE @Verbose VARCHAR(255) = CONCAT('PERCORSO NON TROVATO @Id_Partizione_Sorgente = ', @Id_Partizione_Sorgente,' @Id_Partizione_Destinazione=', @Id_Partizione_Destinazione,' @SORG = ', @SORG,' @DEST = ',@DEST);
			THROW 50001,@Verbose,1
		END
		-- Valorizzo il cursore prendendo gli step normali dei percorsi incrociandoli con le adiacenze composte.
		SET @Cursore = CURSOR LOCAL STATIC FOR
		SELECT	CASE
					WHEN Percorso_Completo.ID_SORGENTE IS NULL THEN NULL 					
					WHEN Percorso_Completo.ID_SORGENTE = ISNULL(@SORG,@Id_Partizione_Sorgente) THEN  @Id_Partizione_Sorgente
					WHEN Percorso_Completo.ID_SORGENTE = ISNULL(@DEST,@Id_Partizione_Destinazione) THEN @Id_Partizione_Destinazione
					ELSE Id_Sorgente
				END ID_SORGENTE,
				CASE 
					WHEN Percorso_Completo.Id_Destinazione IS NULL THEN NULL 					
					WHEN Percorso_Completo.Id_Destinazione = ISNULL(@DEST,@Id_Partizione_Destinazione) THEN @Id_Partizione_Destinazione
					WHEN Percorso_Completo.Id_Destinazione = ISNULL(@SORG,@Id_Partizione_Sorgente) THEN  @Id_Partizione_Sorgente
					ELSE Id_Destinazione
				END Id_Destinazione,
				Descrizione,
				Direzione,
				Id_Tipo_Messaggio,
				StoredProcedure,
				Xml_Param
		FROM	(
					SELECT	Percorso.Colonna.value('@Passo','Int')							Passo,
							Adiacenze_Composte_Abilitate.Id_Partizione_Sorgente				Id_Sorgente,
							Adiacenze_Composte_Abilitate.Id_Partizione_Destinazione			Id_Destinazione,
							Adiacenze_Composte_Abilitate.Descrizione,
							Adiacenze_Composte_Abilitate.Id_Tipo_Messaggio					Id_Tipo_Messaggio,
							NULL															Direzione,
							Adiacenze_Composte_Abilitate.Sequenza,
							Adiacenze_Composte_Abilitate.Stored_Procedure					StoredProcedure,
							CONVERT(Varchar(MAX),Adiacenze_Composte_Abilitate.Xml_Param)	Xml_Param,
							Adiacenze_Composte_Abilitate.Inserimento
					FROM	@Percorso_Calcolato.nodes('//Percorso') Percorso(Colonna)
					JOIN	(
								SELECT	AC.Id_Adiacenza,
										AC.Sequenza,
										Inserimento,
										AC.Id_Partizione_Sorgente,
										AC.Id_Partizione_Destinazione,
										AC.Id_Tipo_Messaggio,
										Stored_Procedure,
										Xml_Param,
										Descrizione
								FROM	Adiacenze_Composte				AC
								LEFT
								JOIN	Adiacenze_Composte_Esclusione	ACE
								ON		ACE.Id_Adiacenza = AC.Id_Adiacenza
									AND ACE.Sequenza = AC.Sequenza
									AND ACE.Id_Tipo_Missione = @Id_Tipo_Missione
								WHERE	Abilitata = 1
									AND ACE.Id_Adiacenza IS NULL
							) Adiacenze_Composte_Abilitate
					ON		Adiacenze_Composte_Abilitate.Id_Adiacenza = Percorso.Colonna.value('@Id_Adiacenza','Int')
						AND (Adiacenze_Composte_Abilitate.Sequenza = Percorso.Colonna.value('@Passo','Int') OR Adiacenze_Composte_Abilitate.Sequenza = 0)
					UNION
					SELECT	Percorso.Colonna.value('@Passo','Int')						Passo,
							Percorso.Colonna.value('@Part_Sorgente','Int')				Id_Sorgente,
							Percorso.Colonna.value('@Part_Destinazione','Int')			Id_Destinazione,
							Percorso.Colonna.value('@Descrizione','Varchar(80)')		Descrizione,
							Percorso.Colonna.value('@Id_Tipo_Messaggio','Varchar(5)')	Id_Tipo_Messaggio,
							Percorso.Colonna.value('@Direzione','Varchar(1)')			Direzione,
							NULL														Sequenza,
							NULL														StoredProcedure,
							NULL														Xml_Param,
							NULL														Inserimento
					FROM	@Percorso_Calcolato.nodes('//Percorso') Percorso(Colonna)
				) Percorso_Completo
		ORDER
			BY	Percorso_Completo.Passo ASC,
				CASE Percorso_Completo.Inserimento
					WHEN 'B' THEN 1
					WHEN 'A' THEN 3
					ELSE ISNULL(Percorso_Completo.Inserimento,2)
				END ASC,
				Percorso_Completo.Sequenza ASC

		OPEN @Cursore
		FETCH NEXT FROM @Cursore INTO
			@Id_Partizione_Sorgente,
			@Id_Partizione_Destinazione,
			@Descrizione,
			@Direzione,
			@Id_Tipo_Messaggio,
			@StoredProcedure,
			@Xml_Param
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Count = ISNULL(@Count,0) + 1	

			IF (@Id_Partizione_Sorgente IS NOT NULL AND @Id_Partizione_Destinazione IS NOT NULL AND @Id_Tipo_Messaggio IS NOT NULL)
				OR
				(@StoredProcedure IS NOT NULL AND @Xml_Param IS NOT NULL)
				-- Nella percorso e poi nella percorso PreCalc			
				INSERT INTO Percorso (Id_Percorso,Sequenza_Percorso,Id_Partizione_Sorgente,Id_Partizione_Destinazione,Descrizione,Id_Tipo_Messaggio,Stored_Procedure,Xml_Param,Id_Tipo_Stato_Percorso,Direzione)
				VALUES (@Id_Missione,@Count,@Id_Partizione_Sorgente,@Id_Partizione_Destinazione,@Descrizione,@Id_Tipo_Messaggio,@StoredProcedure,@Xml_Param,1,@Direzione)

			FETCH NEXT FROM @Cursore INTO
				@Id_Partizione_Sorgente,
				@Id_Partizione_Destinazione,
				@Descrizione,
				@Direzione,
				@Id_Tipo_Messaggio,
				@StoredProcedure,
				@Xml_Param
		END
			
		CLOSE @Cursore
		DEALLOCATE @Cursore			
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

			RETURN 1
		END ELSE THROW
	END CATCH
END





GO
