SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[fn_VerificaPercorsoLibero] (@Id_Percorso Int,@SequenzaPercorso Int)
RETURNS BIT
AS
BEGIN
	DECLARE @PercorsiOpposti TABLE (Id_Percorso Int, Id_Partizione Int)
	DECLARE @Cursore CURSOR
	DECLARE @Id_Partizione_Destinazione Int

	-- Inserisco nella tabella tutte le partizioni coinvolte nel mio percorso ma nel senso contrario.
	INSERT INTO @PercorsiOpposti (Id_Percorso,Id_Partizione)
	SELECT	DISTINCT	unpvt.Id_Percorso
						,unpvt.Id_Partizione
	FROM		
	(SELECT	PercorsoSpeculare.Id_Percorso
			,PercorsoSpeculare.Id_Partizione_Sorgente
			,PercorsoSpeculare.Id_Partizione_Destinazione
	FROM	Percorso 
			INNER JOIN Percorso PercorsoSpeculare ON (Percorso.Id_Partizione_Sorgente = PercorsoSpeculare.Id_Partizione_Destinazione AND Percorso.Id_Partizione_Destinazione = PercorsoSpeculare.Id_Partizione_Sorgente)
	WHERE	Percorso.Id_Percorso = @Id_Percorso	
			AND	Percorso.Sequenza_Percorso >= @SequenzaPercorso) PO
	UNPIVOT  
	(Id_Partizione FOR PartizioneCoinvolta IN (Id_Partizione_Sorgente,Id_Partizione_Destinazione)) unpvt
	
	-- Per ogni passo controllo la destinazione (non la sorgente perchè è quella da cui parto quindi do per scontato che non ci siano problemi con lei). 
	-- Se la destinzione è nella tabella dei percorsi opposti controllo che il passo interessato non sia in esecuzione o eseguito. Se invece non c'è significa che nessun
	-- percorso che sta venendo nella mia direzione sta coinvolgendo quella parte di percorso : ho via libera.
	SET @Cursore = CURSOR LOCAL FAST_FORWARD FOR
	SELECT	Percorso.Id_Partizione_Destinazione
	FROM	Percorso
	WHERE	Percorso.Id_Percorso = @Id_Percorso	
			AND	Percorso.Sequenza_Percorso >= @SequenzaPercorso 
	ORDER BY Sequenza_Percorso ASC
	
	OPEN @Cursore	
	
	FETCH NEXT FROM @Cursore INTO 
	@Id_Partizione_Destinazione
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @Stato_Percorso Int = NULL
		DECLARE @Id_Udc Int = NULL
		
		SELECT	@Stato_Percorso = MAX(CASE Percorso.Id_Tipo_Stato_Percorso WHEN 3 THEN 1 ELSE Percorso.Id_Tipo_Stato_Percorso END)
				,@Id_Udc = MAX(Udc_Posizione.Id_Udc)
		FROM	Percorso
				INNER JOIN	@PercorsiOpposti PercorsiOpposti ON	
							PercorsiOpposti.Id_Percorso = Percorso.Id_Percorso
							AND (Percorso.Id_Partizione_Destinazione = @Id_Partizione_Destinazione OR Percorso.Id_Partizione_Sorgente = @Id_Partizione_Destinazione)
				INNER JOIN	Missioni ON Missioni.Id_Missione = PercorsiOpposti.Id_Percorso
				LEFT  JOIN	Udc_Posizione ON Udc_Posizione.Id_Udc = Missioni.Id_Udc AND Udc_Posizione.Id_Partizione = @Id_Partizione_Destinazione
		WHERE	Percorso.Id_Tipo_Messaggio IN ('1215', '12020')
	
		IF @Stato_Percorso IS NULL RETURN 1
		ELSE IF @Stato_Percorso = 2 OR @Id_Udc IS NOT NULL RETURN 0
	
		FETCH NEXT FROM @Cursore INTO 
		@Id_Partizione_Destinazione
	END
	
	CLOSE @Cursore
	DEALLOCATE @Cursore
	
	RETURN 1
END
GO
