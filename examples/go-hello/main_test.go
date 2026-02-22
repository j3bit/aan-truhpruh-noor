package main

import "testing"

func TestGreeting(t *testing.T) {
	got := greeting("template")
	want := "Hello, template!"
	if got != want {
		t.Fatalf("greeting() = %q, want %q", got, want)
	}
}
