CREATE TABLE [dbo].[Alarms]
(
[AlarmId] [int] NOT NULL IDENTITY(1, 1),
[ErrorCodeId] [int] NOT NULL,
[Status] [int] NOT NULL,
[ResourceName] [nvarchar] (200) COLLATE Latin1_General_CI_AS NULL,
[Date] [datetime] NOT NULL CONSTRAINT [DF_Alarms_Date] DEFAULT (getdate())
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Alarms] ADD CONSTRAINT [PK_Alarms] PRIMARY KEY CLUSTERED ([AlarmId]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Alarms] ADD CONSTRAINT [FK_Alarms_Tipo_ErrorCode] FOREIGN KEY ([ErrorCodeId]) REFERENCES [dbo].[Tipo_ErrorCode] ([Id_ErrorCode])
GO
ALTER TABLE [dbo].[Alarms] ADD CONSTRAINT [FK_Alarms_Tipo_Stato_Evento] FOREIGN KEY ([Status]) REFERENCES [dbo].[Tipo_Stato_Evento] ([Id_Tipo_Stato_Evento])
GO
