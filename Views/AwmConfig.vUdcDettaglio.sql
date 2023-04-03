SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [AwmConfig].[vUdcDettaglio] AS 

SELECT	CONTENUTO.Id_Udc,
		CONTENUTO.Id_UdcDettaglio,
		CONTENUTO.Codice_Articolo,
		CONTENUTO.Descrizione_Articolo,
		CONTENUTO.Quantita_Pezzi,
		CONTENUTO.WBS_Riferimento,
		CONTENUTO.Unita_Misura,
		CONTENUTO.FlagControlloQualita,
		CONTENUTO.MotivoControlloQualita,
		CONTENUTO.Doppio_Step_QM,
		CONTENUTO.FlagNonConformita,
		CONTENUTO.MotivoNonConformita,
		CONTENUTO.Control_Lot,
		UP.Id_Partizione,
		CASE
			WHEN UT.Id_Tipo_Udc IN ('1','2','3') THEN 'A'
			WHEN UT.Id_Tipo_Udc IN ('4','5','6') THEN 'B'
			ELSE UT.Id_Tipo_Udc 
		END			Id_Tipo_Udc
FROM	dbo.Udc_Testata		UT
JOIN	dbo.Udc_Posizione	UP
ON		UP.Id_Udc = UT.Id_Udc
JOIN	
		(
			SELECT	ud.Id_Udc													Id_Udc,
					ud.Id_UdcDettaglio											Id_UdcDettaglio,
					a.Codice													Codice_Articolo,
					a.Descrizione												Descrizione_Articolo,
					CAST(ud.Quantita_Pezzi
						- ISNULL(SUM(cq.Quantita), 0)
						- ISNULL(SUM(nf.Quantita), 0)	AS NUMERIC(10,2))		Quantita_Pezzi,
					WBS_Riferimento												WBS_Riferimento,
					a.Unita_Misura												Unita_Misura,
					0															FlagControlloQualita,
					''															MotivoControlloQualita,
					0															Doppio_Step_QM,
					0															FlagNonConformita,
					''															MotivoNonConformita,
					''															Control_Lot
			FROM	Udc_Dettaglio	ud
			JOIN	Articoli		a
			ON		a.Id_Articolo = ud.Id_Articolo
			LEFT
			JOIN	Custom.ControlloQualita cq
			ON		cq.Id_UdcDettaglio = ud.Id_UdcDettaglio
			LEFT
			JOIN	Custom.NonConformita	nf
			ON		nf.Id_UdcDettaglio = ud.Id_UdcDettaglio
			GROUP
				BY	ud.Id_Udc,ud.Id_UdcDettaglio,a.Codice,a.Descrizione, UD.Quantita_Pezzi,WBS_Riferimento,a.Unita_Misura
			HAVING	(ud.Quantita_Pezzi
						- ISNULL(SUM(cq.Quantita), 0)
						- ISNULL(SUM(nf.Quantita), 0)) > 0
			UNION ALL
			SELECT  ud.Id_Udc								Id_Udc,
					ud.Id_UdcDettaglio						Id_UdcDettaglio,
					a.Codice								Codice_Articolo,
					a.Descrizione							Descrizione_Articolo,
					cq.Quantita								Quantita_Pezzi,
					ud.WBS_Riferimento						WBS_Riferimento,
					a.Unita_Misura							Unita_Misura,
					1										FlagControlloQualita,
					cq.MotivoQualita						MotivoControlloQualita,
					ISNULL(cq.Doppio_Step_QM,0)				Doppio_Step_QM,
					0										FlagNonConformita,
					NULL									MotivoNonConformita,
					CQ.CONTROL_LOT							Control_Lot
			FROM	Custom.ControlloQualita cq
			JOIN	Udc_Dettaglio			ud
			ON		ud.Id_UdcDettaglio = cq.Id_UdcDettaglio
			JOIN	Articoli				a
			ON		a.Id_Articolo = ud.Id_Articolo
			WHERE	cq.Quantita > 0
			UNION ALL
			SELECT  ud.Id_Udc								Id_Udc,
					ud.Id_UdcDettaglio						Id_UdcDettaglio,
					a.Codice 								Codice_Articolo,
					a.Descrizione 							Descrizione_Articolo,
					nf.Quantita								Quantita_Pezzi,
					ud.WBS_Riferimento						WBS_Riferimento,
					a.Unita_Misura							Unita_Misura,
					0										FlagControlloQualita,
					''										MotivoControlloQualita,
					0										Doppio_Step_QM,
					1										FlagNonConformita,
					nf.MotivoNonConformita					MotivoNonConformita,
					NF.CONTROL_LOT							Control_Lot
			FROM	Custom.NonConformita	nf
			JOIN	Udc_Dettaglio			ud
			ON		ud.Id_UdcDettaglio = nf.Id_UdcDettaglio
			JOIN	Articoli				a
			ON		a.Id_Articolo = ud.Id_Articolo
			WHERE	nf.Quantita > 0
		)	CONTENUTO
ON		CONTENUTO.Id_Udc = UT.Id_Udc
GO
