SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [AwmConfig].[vUdcRighePrelievo]
AS
SELECT	mpd.Id_Riga_Lista,
		mpd.Id_Testata_Lista,
		tlp.ORDER_ID,
		tlp.ORDER_TYPE,
		rlp.PROD_LINE		LINEA_PRODUZIONE_DESTINAZIONE, 
		rlp.PROD_ORDER		CODICE_PRODUZIONE_ERP,
		a.Codice			CODICE_ARTICOLO, 
		a.Descrizione		DESCRIZIONE_ARTICOLO, 
		mpd.Quantita		QuantitaDaPrelevare, 
        mpd.Qta_Prelevata	QuantitaPrelevata,
		CASE
			WHEN mpd.Qta_Prelevata = 0 THEN mpd.Quantita
			ELSE mpd.Qta_Prelevata
		END					QUANTITA_ETICHETTA,
		tlp.FL_LABEL,
		a.Unita_Misura		UDM,
		tlp.PFIN,
		CASE
			WHEN rlp.COMM_PROD IS NOT NULL THEN rlp.COMM_PROD
			ELSE tlp.COMM_PROD
		END					COMM_PROD,
		CASE
			WHEN rlp.COMM_SALE IS NOT NULL THEN rlp.COMM_SALE
			ELSE tlp.COMM_SALE
		END					COMM_SALE,
		ev.Id_Evento
		--,rlp.SAP_DOC_NUM
		--,tlp.DES_PREL_CONF
FROM	dbo.Eventi				ev
JOIN	dbo.Udc_Testata			ut
ON		ut.Id_Udc = ev.Xml_Param.value('data(//Parametri//Id_Udc)[1]', 'NUMERIC(18,0)')
JOIN	dbo.Missioni_Picking_Dettaglio		mpd
ON		mpd.Id_Udc = ut.Id_Udc
	AND mpd.Id_Testata_Lista = ev.Xml_Param.value('data(//Parametri//Id_Testata_Lista)[1]', 'INT')
	AND ISNULL(MPD.FL_MANCANTI,0) = 0
JOIN	dbo.Articoli						a
ON		mpd.Id_Articolo = a.Id_Articolo
JOIN	Custom.RigheListePrelievo			rlp
ON		mpd.Id_Riga_Lista = rlp.ID
JOIN	Custom.TestataListePrelievo			tlp
ON		rlp.Id_Testata = tlp.ID
WHERE   ev.Id_Tipo_Evento = 4
	AND ev.Id_Tipo_Stato_Evento = 1
	AND mpd.Qta_Prelevata < mpd.Quantita
	AND mpd.Id_Stato_Missione IN (2,3)
GO
EXEC sp_addextendedproperty N'MS_DiagramPane1', N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "ev"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 238
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "ut"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 266
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "mpd"
            Begin Extent = 
               Top = 270
               Left = 38
               Bottom = 400
               Right = 266
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "a"
            Begin Extent = 
               Top = 6
               Left = 276
               Bottom = 136
               Right = 450
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "rlp"
            Begin Extent = 
               Top = 402
               Left = 38
               Bottom = 532
               Right = 259
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End', 'SCHEMA', N'AwmConfig', 'VIEW', N'vUdcRighePrelievo', NULL, NULL
GO
EXEC sp_addextendedproperty N'MS_DiagramPane2', N'
', 'SCHEMA', N'AwmConfig', 'VIEW', N'vUdcRighePrelievo', NULL, NULL
GO
DECLARE @xp int
SELECT @xp=2
EXEC sp_addextendedproperty N'MS_DiagramPaneCount', @xp, 'SCHEMA', N'AwmConfig', 'VIEW', N'vUdcRighePrelievo', NULL, NULL
GO
