CREATE TABLE [dbo].[Tipo_Valori]
(
[Id_Tipo_Valore] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Tipo_Dato] [varchar] (12) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Valori] ADD CONSTRAINT [PK_Tipo_Valori] PRIMARY KEY CLUSTERED ([Id_Tipo_Valore]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Valori] ADD CONSTRAINT [FK_Tipo_Valori_Tipo_Dati] FOREIGN KEY ([Id_Tipo_Dato]) REFERENCES [dbo].[Tipo_Dati] ([Id_Tipo_Dato])
GO
