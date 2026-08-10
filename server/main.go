package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	dbPath := flag.String("db", "./luogo-relay.db", "sqlite database path")
	maxLog := flag.Int("max-log", 500, "messages kept per group")
	cert := flag.String("tls-cert", "", "path to TLS certificate (enables HTTPS)")
	key := flag.String("tls-key", "", "path to TLS private key")
	flag.Parse()

	store, err := NewStore(*dbPath)
	if err != nil {
		log.Fatalf("store: %v", err)
	}
	defer store.Close()

	srv := NewServer(store, NewHub(), *maxLog)
	httpSrv := &http.Server{
		Addr:              *addr,
		Handler:           srv.routes(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("luogo relay listening on %s (db: %s)", *addr, *dbPath)
		var err error
		if *cert != "" && *key != "" {
			err = httpSrv.ListenAndServeTLS(*cert, *key)
		} else {
			err = httpSrv.ListenAndServe()
		}
		if err != nil && err != http.ErrServerClosed {
			log.Fatalf("server: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop
	log.Println("shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpSrv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}
