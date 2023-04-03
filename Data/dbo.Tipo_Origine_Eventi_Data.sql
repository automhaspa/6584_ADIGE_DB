SET IDENTITY_INSERT [dbo].[Tipo_Origine_Eventi] ON
INSERT INTO [dbo].[Tipo_Origine_Eventi] ([Id_Tipo_Origine_Evento], [Sigla], [Descrizione]) VALUES (1, 'PLC', 'Eventi generati dai controlli PLC, sia essi frutto di un operazione manuale o automatica.')
INSERT INTO [dbo].[Tipo_Origine_Eventi] ([Id_Tipo_Origine_Evento], [Sigla], [Descrizione]) VALUES (2, 'PCM', 'Eventi generati dal componente di comunicazione.')
INSERT INTO [dbo].[Tipo_Origine_Eventi] ([Id_Tipo_Origine_Evento], [Sigla], [Descrizione]) VALUES (3, 'AWM', 'Eventi generati dall''interfaccia.')
INSERT INTO [dbo].[Tipo_Origine_Eventi] ([Id_Tipo_Origine_Evento], [Sigla], [Descrizione]) VALUES (4, 'SQL', 'Eventi provenienti dalla procedure di gestione dell''impianto o dal motore di SQL.')
SET IDENTITY_INSERT [dbo].[Tipo_Origine_Eventi] OFF
