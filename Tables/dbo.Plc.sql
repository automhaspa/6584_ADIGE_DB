CREATE TABLE [dbo].[Plc]
(
[Id_Plc] [int] NOT NULL IDENTITY(1, 1),
[RemoteIP] [varchar] (15) COLLATE Latin1_General_CI_AS NOT NULL,
[SendRemotePort] [int] NOT NULL,
[ReceiveRemotePort] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Plc] ADD CONSTRAINT [PK_Plc] PRIMARY KEY CLUSTERED ([Id_Plc]) ON [PRIMARY]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Porta di connessione per il canale Receive.', 'SCHEMA', N'dbo', 'TABLE', N'Plc', 'COLUMN', N'ReceiveRemotePort'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Indirizzo IP del PLC.', 'SCHEMA', N'dbo', 'TABLE', N'Plc', 'COLUMN', N'RemoteIP'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Porta di connessione per il canale Send.', 'SCHEMA', N'dbo', 'TABLE', N'Plc', 'COLUMN', N'SendRemotePort'
GO
