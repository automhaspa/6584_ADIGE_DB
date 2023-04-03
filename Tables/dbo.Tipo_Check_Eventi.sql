CREATE TABLE [dbo].[Tipo_Check_Eventi]
(
[Id_Tipo_Check_Evento] [int] NOT NULL IDENTITY(1, 1),
[Sigla] [varchar] (3) COLLATE Latin1_General_CI_AS NULL,
[Descrizione] [varchar] (150) COLLATE Latin1_General_CI_AS NULL,
[Variabile] [bit] NOT NULL CONSTRAINT [DF_Tipo_Check_Eventi_Variabile] DEFAULT ((1)),
[Id_Tipo_Check_Evento_Variazione] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Check_Eventi] ADD CONSTRAINT [PK_Tipo_Check_Eventi] PRIMARY KEY CLUSTERED ([Id_Tipo_Check_Evento]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Check_Eventi] ADD CONSTRAINT [FK_Tipo_Check_Eventi_Tipo_Check_Eventi] FOREIGN KEY ([Id_Tipo_Check_Evento_Variazione]) REFERENCES [dbo].[Tipo_Check_Eventi] ([Id_Tipo_Check_Evento])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Id_Tipo_Check_Evento in cui l''Evento viene valorizzato al check.', 'SCHEMA', N'dbo', 'TABLE', N'Tipo_Check_Eventi', 'COLUMN', N'Id_Tipo_Check_Evento_Variazione'
GO
