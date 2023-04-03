CREATE TABLE [dbo].[Tipo_Missioni]
(
[Id_Tipo_Missione] [varchar] (3) COLLATE Latin1_General_CI_AS NOT NULL,
[Priorita] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Selectable] [bit] NOT NULL,
[Icona] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Missioni] ADD CONSTRAINT [PK_Tipo_Missioni] PRIMARY KEY CLUSTERED ([Id_Tipo_Missione]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Missioni] ADD CONSTRAINT [FK_Tipo_Missioni_Tipo_Priorita] FOREIGN KEY ([Priorita]) REFERENCES [dbo].[Tipo_Priorita] ([Priorita])
GO
