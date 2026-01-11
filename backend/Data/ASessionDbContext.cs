using Microsoft.EntityFrameworkCore;
using ASession.Models;

namespace ASession.Data
{
    public class ASessionDbContext : DbContext
    {
        public ASessionDbContext(DbContextOptions<ASessionDbContext> options) : base(options)
        {
        }
        
        public DbSet<User> Users { get; set; }
        public DbSet<Team> Teams { get; set; }
        public DbSet<TeamMember> TeamMembers { get; set; }
        public DbSet<SheetMusic> SheetMusics { get; set; }
        public DbSet<MidiFile> MidiFiles { get; set; }
        public DbSet<Recording> Recordings { get; set; }
        public DbSet<PracticeSchedule> PracticeSchedules { get; set; }
        public DbSet<OtpCode> OtpCodes { get; set; }
        
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            // Configure composite unique keys
            modelBuilder.Entity<TeamMember>()
                .HasIndex(tm => new { tm.TeamId, tm.UserId })
                .IsUnique();
            
            // Configure relationships
            modelBuilder.Entity<TeamMember>()
                .HasOne(tm => tm.Team)
                .WithMany(t => t.TeamMembers)
                .HasForeignKey(tm => tm.TeamId)
                .OnDelete(DeleteBehavior.Cascade);
                
            modelBuilder.Entity<TeamMember>()
                .HasOne(tm => tm.User)
                .WithMany(u => u.TeamMembers)
                .HasForeignKey(tm => tm.UserId)
                .OnDelete(DeleteBehavior.Cascade);
                
            modelBuilder.Entity<SheetMusic>()
                .HasOne(sm => sm.Team)
                .WithMany(t => t.SheetMusics)
                .HasForeignKey(sm => sm.TeamId)
                .OnDelete(DeleteBehavior.Cascade);
                
            modelBuilder.Entity<SheetMusic>()
                .HasOne(sm => sm.CreatedByUser)
                .WithMany(u => u.CreatedSheetMusics)
                .HasForeignKey(sm => sm.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
                
            modelBuilder.Entity<MidiFile>()
                .HasOne(mf => mf.SheetMusic)
                .WithMany(sm => sm.MidiFiles)
                .HasForeignKey(mf => mf.SheetMusicId)
                .OnDelete(DeleteBehavior.Cascade);
                
            modelBuilder.Entity<Recording>()
                .HasOne(r => r.MidiFile)
                .WithMany(mf => mf.Recordings)
                .HasForeignKey(r => r.MidiFileId)
                .OnDelete(DeleteBehavior.SetNull);
                
            modelBuilder.Entity<Recording>()
                .HasOne(r => r.RecordedByUser)
                .WithMany(u => u.Recordings)
                .HasForeignKey(r => r.RecordedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
                
            modelBuilder.Entity<PracticeSchedule>()
                .HasOne(ps => ps.Team)
                .WithMany(t => t.PracticeSchedules)
                .HasForeignKey(ps => ps.TeamId)
                .OnDelete(DeleteBehavior.Cascade);

            // OTP
            modelBuilder.Entity<OtpCode>()
                .HasIndex(o => new { o.UserId, o.Purpose, o.Code })
                .IsUnique();
            modelBuilder.Entity<OtpCode>()
                .HasOne(o => o.User)
                .WithMany()
                .HasForeignKey(o => o.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}