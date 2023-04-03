CREATE TABLE [Printer].[Printer]
(
[Id_Printer] [int] NOT NULL,
[Name] [varchar] (25) COLLATE Latin1_General_CI_AS NOT NULL,
[Type] [varchar] (20) COLLATE Latin1_General_CI_AS NOT NULL,
[IpAdress] [varchar] (15) COLLATE Latin1_General_CI_AS NOT NULL,
[Port] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [Printer].[Printer] ADD CONSTRAINT [PK__Printer__C623CE9694B483C3] PRIMARY KEY CLUSTERED ([Id_Printer]) ON [PRIMARY]
GO
