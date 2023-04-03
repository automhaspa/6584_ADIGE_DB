SET IDENTITY_INSERT [dbo].[Plc] ON
INSERT INTO [dbo].[Plc] ([Id_Plc], [RemoteIP], [SendRemotePort], [ReceiveRemotePort]) VALUES (1, '172.31.1.1', 2011, 2012)
INSERT INTO [dbo].[Plc] ([Id_Plc], [RemoteIP], [SendRemotePort], [ReceiveRemotePort]) VALUES (2, 'NON DEFINITO', 0, 0)
SET IDENTITY_INSERT [dbo].[Plc] OFF
